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

    def list_images(self):
        return self.conn.compute.images()

    def list_flavors(self):
        return self.conn.compute.flavors()

    def find_flavor(self, flavor_name):
        return self.conn.compute.find_flavor(flavor_name)

    def provision_vm(self, name, image, flavor, keypair, network, security_groups, server_group, user_data):
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

    def delete_vm(self, name):
        self.conn.compute.delete_server(self.conn.compute.find_server(name))


if __name__ == '__main__':
    driver = OpenStackDriver(dict(OPENSTACK_CREDENTIALS_FILE=os.environ.get('OPENSTACK_CREDENTIALS_FILE')))
    driver.connect()
    print(driver.list_servers())
    print(driver.list_flavors())
    print(driver.list_images())
    print(driver.find_flavor('io.70GB'))
