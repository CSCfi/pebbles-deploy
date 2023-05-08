import logging
import os
import signal
from time import sleep

import kubernetes
import yaml
from openshift.dynamic import DynamicClient

from scaler import Scaler

# global flag to shut down
terminate = False


def handler(signum, frame):
    global terminate
    terminate = True


def create_kube_client():
    return kubernetes.config.new_client_from_config(config_file=os.environ.get('KUBECONFIG_FILE', '.kube/config'))


def main():
    logging.basicConfig(level=logging.INFO, format='%(levelname)s - %(message)s')
    logging.info('Starting autoscaler')

    global terminate
    # wire our handler to
    # - SIGTERM for controlled shutdowns by systemd
    signal.signal(signal.SIGTERM, handler)

    dc = DynamicClient(create_kube_client())

    config_file = os.environ.get('AUTOSCALER_CONFIG_FILE', 'autoscaler_config.yaml')
    config_file_stat = os.stat(config_file)
    config = yaml.safe_load(open(config_file, 'r'))

    scaler = Scaler(dc, config)
    while not terminate:
        # refresh config if it has been modified
        new_stat = os.stat(config_file)
        if new_stat.st_mtime != config_file_stat.st_mtime:
            config_file_stat = new_stat
            config = yaml.safe_load(open(config_file, 'r'))
            scaler.set_config(config)

        # run actual update
        scaler.update()

        # check signaled termination while sleeping
        for i in range(60):
            if terminate:
                break
            sleep(1)

    logging.info('Stopping autoscaler')


if __name__ == '__main__':
    main()
