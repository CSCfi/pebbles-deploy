import logging
import random

import yaml

import utils


class ImagePuller:
    """
    Class to warm cache on cluster nodes
    """

    def __init__(self, dynamic_client, config):
        self.dynamic_client = dynamic_client
        self.config = config

    def update(self, target_nodes, reference_pods):
        """This method extracts a list of images in given pods and creates pull-jobs on given nodes"""

        # first extract images from running pods
        images = ImagePuller._find_active_images(reference_pods)

        # find out a list of node-image pairs for missing images
        missing_pairs = ImagePuller.find_missing_node_image_pairs(target_nodes, images)

        # then select one pair of node-image to pull, if any
        if missing_pairs:
            node, image = ImagePuller._select_node_and_image(missing_pairs)
            ImagePuller._pull(self.dynamic_client, node, image)

        # TODO: add support for a static list of images, perhaps a ConfigMap in the cluster

    @staticmethod
    def _find_active_images(pods):
        """Extracts a list of images from running pods"""
        res = []
        # we'll put images from most recent pods to the top of the list
        pods = sorted(pods, key=lambda x: x.metadata.creationTimestamp, reverse=True)
        for pod in pods:
            if pod.status.phase != 'Running':
                continue
            for image in [c.image for c in pod.spec.containers]:
                if image not in res:
                    res.append(image)
        return res

    @staticmethod
    def find_missing_node_image_pairs(nodes, images):
        """Finds out a list of images missing from nodes"""
        missing_pairs = []
        for node in nodes:
            images_on_node = ImagePuller._extract_images_from_node(node)
            for image in images:
                if image not in images_on_node:
                    missing_pairs.append((node, image))
        return missing_pairs

    @staticmethod
    def _select_node_and_image(missing_pairs):
        """Selects one pair to pull"""
        # Usually take the first item in the list, assuming priority. To avoid getting stuck in case there are some
        # unexpected problems with that item, sometimes take a random entry
        if random.random() > 0.1:
            return missing_pairs[0]
        return random.choice(missing_pairs)

    @staticmethod
    def _extract_images_from_node(node):
        """Lists images from given node"""
        res = []
        for image in node.status.get('images', []):
            res.extend(image.names)
        return res

    @staticmethod
    def _pull(dynamic_client, node, image):
        """Creates a pull-job for given node and image. In case there is already a job running, it does nothing"""
        node_name = node.metadata.name
        api = dynamic_client.resources.get(api_version='batch/v1', kind='Job')

        existing_jobs = api.get(
            namespace='default',
            field_selector='metadata.name=pull-job'
        )

        if existing_jobs.items:
            logging.info('pull job that started at %s is still active', existing_jobs.items[0].status.startTime)
            return

        logging.info('pulling %s on %s', image, node_name)

        job_yaml = utils.parse_jinja2('pull-job.yaml.j2', dict(node=node_name, image=image))
        logging.debug('creating job\n%s' % job_yaml)

        return api.create(body=yaml.safe_load(job_yaml), namespace='default')
