import logging
import os
import random
import string
import subprocess
import time
from time import sleep

import dateutil.parser

import utils
from openstack_driver import OpenStackDriver


def extract_pod_reserved_memory(pod):
    mem = 0
    for container in pod.spec.containers:
        if container.resources.limits:
            if container.resources.limits.memory:
                mem += utils.parse_memspec_to_bytes(container.resources.limits.memory)
    return mem


def is_pod_safe_to_evict(pod):
    if not pod.metadata.get('annotations'):
        return False

    return pod.metadata.annotations.get('cluster-autoscaler.kubernetes.io/safe-to-evict', 'false') == 'true'


def is_old_node(node, limit_in_seconds):
    return time.time() - dateutil.parser.isoparse(node.metadata.creationTimestamp).timestamp() > limit_in_seconds


class Scaler:

    def __init__(self, dynamic_client, config):
        self.dc = dynamic_client

        self.config = config

        self.free_memory_target = 0
        self.old_node_age_limit_sec = 0
        self.maximum_number_of_nodes = 0

        self.nodes = []
        self.pods = []

        self.total_user_node_memory = 0
        self.total_projected_user_node_memory = 0
        self.total_reserved_memory = 0
        self.total_projected_free_memory = 0
        self.free_memory = 0

        self.set_config(config)

    def set_config(self, config):

        self.config = config
        self.free_memory_target = utils.parse_memspec_to_bytes(self.config.get('freeMemoryTarget'))
        self.old_node_age_limit_sec = self.config.get('oldNodeAgeLimitHours', 7 * 24) * 60 * 60
        self.maximum_number_of_nodes = self.config.get('maximumNumberOfNodes')

        logging.info('Setting config')
        for key in ('clusterName', 'flavor', 'image',
                    'freeMemoryTarget', 'maximumNumberOfNodes', 'oldNodeAgeLimitHours'):
            logging.info('  %s: %s', key, config.get(key))

    def update(self):
        self._refresh_resource_data()

        logging.info(
            'mem GiB: %.1f total %.1f proj %.1f alloc %.1f free %.1f proj_free %.1f tgt | '
            'nodes: %d active %d old %d cordoned %d max',
            self.total_user_node_memory / utils.UNIT_FACTORS.get('Gi'),
            self.total_projected_user_node_memory / utils.UNIT_FACTORS.get('Gi'),
            self.total_reserved_memory / utils.UNIT_FACTORS.get('Gi'),
            self.free_memory / utils.UNIT_FACTORS.get('Gi'),
            self.total_projected_free_memory / utils.UNIT_FACTORS.get('Gi'),
            self.free_memory_target / utils.UNIT_FACTORS.get('Gi'),
            len(self._get_active_user_nodes()),
            len(self._get_old_nodes()),
            len(self._get_cordoned_nodes()),
            self.maximum_number_of_nodes,
        )

        # perform one update action

        # scale up
        if self.total_projected_free_memory < self.free_memory_target:
            if len(self._get_user_nodes()) < self.maximum_number_of_nodes:
                self._scale_up()
                return
            else:
                logging.info('maximum number of nodes reached: %d', self.maximum_number_of_nodes)

        # mark old nodes unschedulable, if there is room
        if self.total_projected_free_memory > self.free_memory_target:
            old_nodes = self._get_old_nodes()
            if old_nodes:
                self._cordon_node(old_nodes[0].metadata.name)
                return

        # remove empty unschedulable nodes
        expired_nodes = self._get_expired_nodes()
        if len(expired_nodes) > 0:
            self._scale_down(expired_nodes[0].metadata.name)
            return

    def _refresh_resource_data(self):
        api_node = self.dc.resources.get(api_version='v1', kind='Node')
        self.nodes = [n for n in api_node.get().items]

        api_pod = self.dc.resources.get(api_version='v1', kind='Pod')
        self.pods = [p for p in api_pod.get().items]

        # memory for all currently active user nodes
        self.total_user_node_memory = sum(
            [utils.parse_memspec_to_bytes(n.status.capacity.memory) for n in self._get_active_user_nodes()])

        # memory for all currently active user nodes that are old enough to be recycled
        total_old_node_memory = sum(
            [utils.parse_memspec_to_bytes(n.status.capacity.memory) for n in self._get_old_nodes()])

        # projected memory
        self.total_projected_user_node_memory = self.total_user_node_memory - total_old_node_memory

        active_user_node_names = [n.metadata.name for n in self._get_active_user_nodes()]
        pods_on_user_nodes = [
            p for p in self.pods
            if not p.spec.nodeName or p.spec.nodeName in active_user_node_names
        ]

        self.total_reserved_memory = sum([extract_pod_reserved_memory(p) for p in pods_on_user_nodes])
        self.free_memory = self.total_user_node_memory - self.total_reserved_memory
        self.total_projected_free_memory = self.total_projected_user_node_memory - self.total_reserved_memory

    def _scale_up(self):
        logging.info('Scaling up')

        cluster_name = self.config.get('clusterName')
        random_chars = ''.join(random.SystemRandom().choice(string.ascii_lowercase + string.digits) for _ in range(8))
        node_name = cluster_name + '-node-' + random_chars

        butane_config = utils.parse_jinja2(
            self.config.get('butaneConfigTemplate'),
            dict(server_name=node_name, **self.config.get('butaneConfigData'))
        )
        ignition_data = subprocess.run(
            self.config.get('butaneBinary'),
            input=butane_config.encode('ascii'),
            capture_output=True
        ).stdout

        osd = OpenStackDriver(dict(OPENSTACK_CREDENTIALS_FILE=os.environ.get('OPENSTACK_CREDENTIALS_FILE')))
        osd.connect()

        server = osd.provision_vm(
            name=node_name,
            image=self.config.get('image'),
            flavor=self.config.get('flavor'),
            keypair=cluster_name,
            network=cluster_name + '-network',
            security_groups=[cluster_name + '-common', cluster_name + '-node'],
            server_group=cluster_name + '-server_group_node',
            user_data=ignition_data
        )

        logging.info('Provisioned VM %s %s', server.name, server.id)

        start_ts = time.time()
        while True:
            logging.info('...waiting for the node %s to join', node_name)
            self._refresh_resource_data()

            if node_name in (n.metadata.name for n in self._get_active_user_nodes()):
                logging.info('node %s is now ready', node_name)
                break

            if time.time() - start_ts > 15 * 60:
                logging.error('node %s failed to become ready', node_name)
                raise RuntimeError('node %s failed to become ready' % node_name)

            sleep(30)

    def _cordon_node(self, node_name):
        logging.info('Cordoning node %s', node_name)
        api_node = self.dc.resources.get(api_version='v1', kind='Node')
        body = dict(
            kind='Node',
            apiVersion='v1',
            metadata=dict(name=node_name),
            spec=dict(unschedulable=True),
        )
        api_node.patch(body=body)

    def _scale_down(self, node_name):
        logging.info('Scaling down by removing node %s', node_name)
        api_node = self.dc.resources.get(api_version='v1', kind='Node')
        api_node.delete(name=node_name)
        osd = OpenStackDriver(dict(OPENSTACK_CREDENTIALS_FILE=os.environ.get('OPENSTACK_CREDENTIALS_FILE')))
        osd.connect()
        osd.delete_vm(node_name)
        logging.info('Deleted node and VM %s', node_name)

    def _get_expired_nodes(self):
        # find out nodes that can be taken out of the cluster
        res = []
        for n in self._get_cordoned_nodes():
            # no actual workloads running?
            if len([p for p in self.pods if p.spec.nodeName == n.metadata.name and not is_pod_safe_to_evict(p)]) > 0:
                continue
            res.append(n)

        return res

    def _get_active_user_nodes(self):
        return [
            n for n in self.nodes
            if n.metadata.get('labels', {}).get('role') == 'user'
               and not n.spec.get('unschedulable')
               and len(n.spec.taints) <= 1
        ]

    def _get_user_nodes(self):
        return [
            n for n in self.nodes
            if n.metadata.get('labels', {}).get('role') == 'user'
        ]

    def _get_old_nodes(self):
        return [
            n for n in self._get_active_user_nodes()
            if is_old_node(n, self.old_node_age_limit_sec)
        ]

    def _get_cordoned_nodes(self):
        return [
            n for n in self._get_user_nodes()
            if len([x for x in n.spec.taints if x.key == 'node.kubernetes.io/unschedulable']) == 1
        ]
