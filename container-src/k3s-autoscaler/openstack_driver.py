import base64
import logging
import os

import openstack
import yaml


def get_openstack_credentials(config):
    if config:
        if config.get('OPENSTACK_CREDENTIALS_FILE'):
            logging.debug("Loading credentials from %s" % config.get('OPENSTACK_CREDENTIALS_FILE'))
            source_config = yaml.safe_load(open(config.get('OPENSTACK_CREDENTIALS_FILE')))
        else:
            logging.debug("Using config as provided")
            source_config = config
    else:
        logging.debug("no config, trying environment vars")
        source_config = os.environ

    return dict(
        version='2.1',
        auth_url=source_config['OS_AUTH_URL'],
        username=source_config['OS_USERNAME'],
        password=source_config['OS_PASSWORD'],
        project_id=source_config['OS_TENANT_ID'],
        user_domain_id='default')


class OpenStackDriver:

    def __init__(self, config):
        self.config = config
        self.conn = None

    def connect(self):
        self.conn = openstack.connect(app_name='autoscaler', **get_openstack_credentials(self.config))

    def list_servers(self):
        return self.conn.compute.servers()

    def list_volumes(self):
        return self.conn.block_storage.volumes()

    def find_volume(self, volume_name):
        return self.conn.block_storage.find_volume(volume_name)

    def list_images(self):
        return self.conn.compute.images()

    def list_flavors(self):
        return self.conn.compute.flavors()

    def find_flavor(self, flavor_name):
        return self.conn.compute.find_flavor(flavor_name)

    def create_server(self, name, image, flavor, keypair, network, security_groups, server_group, user_data):
        logging.debug('Creating server %s' % name)
        sec_groups = [dict(name=x) for x in security_groups]
        server_group_id = self.conn.compute.find_server_group(server_group).id
        server = self.conn.compute.create_server(
            name=name,
            image_id=self.conn.compute.find_image(image).id,
            flavor_id=self.conn.compute.find_flavor(flavor).id,
            key_name=keypair,
            networks=[{'uuid': self.conn.network.find_network(network).id}],
            security_groups=sec_groups,
            scheduler_hints=dict(group=server_group_id),
            user_data=base64.b64encode(user_data).decode('utf-8'),
        )

        return server

    def delete_server(self, name):
        logging.debug('Deleting server %s' % name)
        self.conn.compute.delete_server(self.conn.compute.find_server(name))

    def create_volume(self, volume_name, volume_size):
        logging.debug('Creating volume %s' % volume_name)
        volume = self.conn.block_storage.create_volume(name=volume_name, size=volume_size)
        return volume

    def delete_volume(self, name):
        logging.debug('Deleting volume %s' % name)
        self.conn.block_storage.delete_volume(self.conn.block_storage.find_volume(name))

    def attach_volume(self, server_name, volume_name):
        logging.debug('Attaching volume %s to server %s', volume_name, server_name)
        # we need to wait for the server to be active before attempting to attach the disk
        server = self.conn.compute.find_server(server_name)
        self.conn.compute.wait_for_server(server)
        self.conn.compute.create_volume_attachment(
            server,
            self.conn.block_storage.find_volume(volume_name)
        )

    def detach_volume(self, server_name, volume_name):
        logging.debug('Detaching volume %s from server %s', volume_name, server_name)
        server = self.conn.compute.find_server(server_name)
        volume = self.conn.block_storage.find_volume(volume_name)
        self.conn.compute.delete_volume_attachment(server, volume)
        self.conn.block_storage.wait_for_status(volume, status='available')


if __name__ == '__main__':
    driver = OpenStackDriver(dict(OPENSTACK_CREDENTIALS_FILE=os.environ.get('OPENSTACK_CREDENTIALS_FILE')))
    driver.connect()
    print(driver.list_servers())
    print(driver.list_volumes())
    print(driver.list_flavors())
    print(driver.list_images())
    print(driver.find_flavor('io.70GB'))
