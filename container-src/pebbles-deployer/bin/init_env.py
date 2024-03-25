#!/usr/bin/env python
"""
Script to initializes deployment container for Helm + Kustomize based environments. This script is expected to be run
as part of init_env.bash based startup.

The deployment data (credentials, namespace definition) is defined in .env.yaml and .env_secrets.yaml files.

Requires ENV_BASE_DIR environment variable to be set and pointing to the base directory of the environment.
"""

import getpass
import os.path
import pathlib
import subprocess
from os.path import expanduser

import jinja2
import yaml


def read_env_def():
    """ Read environment definition from .env.yaml and .env_secrets.yaml."""
    env_def = yaml.safe_load(open(f'{os.environ["ENV_BASE_DIR"]}/.env.yaml', 'r'))
    res = subprocess.run(
        args=f'sops --decrypt {os.environ["ENV_BASE_DIR"]}/.env_secrets.yaml'.split(),
        check=True,
        capture_output=True
    )
    env_def |= yaml.safe_load(res.stdout)
    return env_def


def format_with_jinja2(template_string, values):
    """ Render given string and values with jinja2."""
    if not template_string:
        return template_string
    return jinja2.Template(template_string).render(values)


def init_age_secret_key():
    """ Obtain age secret key and generate public key. Symlink private key to well known location for sops."""
    pathlib.Path('/dev/shm/secret/').mkdir(mode=0o700, parents=True, exist_ok=True)
    if 'AGE_KEY_FILE' in os.environ:
        print('Using AGE_KEY_FILE %s' % os.environ['AGE_KEY_FILE'])
        pathlib.Path('/dev/shm/secret/age.secret.key').symlink_to(os.environ['AGE_KEY_FILE'])

    if not os.path.exists('/dev/shm/secret/age.secret.key'):
        age_secret_key = getpass.getpass("age secret key: ")
        with open('/dev/shm/secret/age.secret.key', mode='w') as f:
            f.write(age_secret_key)
            f.write('\n')
        os.chmod('/dev/shm/secret/age.secret.key', 0o600)
        print('Wrote secret key to /dev/shm/secret/age.secret.key')

    if not os.path.exists('/dev/shm/secret/age.public.key'):
        subprocess.run(
            args='age-keygen -y -o /dev/shm/secret/age.public.key /dev/shm/secret/age.secret.key'.split(),
            check=True,
        )
        print('Generated public key /dev/shm/secret/age.public.key')

    pathlib.Path(expanduser('~/.config/sops/age')).mkdir(mode=0o700, parents=True, exist_ok=True)
    if not os.path.exists(expanduser('~/.config/sops/age/keys.txt')):
        os.symlink('/dev/shm/secret/age.secret.key', expanduser('~/.config/sops/age/keys.txt'))
        print('Linked secret key to', expanduser('~/.config/sops/age/keys.txt'))


DEPLOYMENT_DATA_TEMPLATE = """\
# Deployment data generated by pebbles-deployer
export DEPLOYMENT_TYPE="{{ deployment_type | d('helm') }}"
export DEPLOYMENT_ROLE="{{ deployment_role | d('development') }}"
export PUBLIC_DOMAIN_NAME="{{ domain_name | d('domain_name_not_set')}}"
export PUBLIC_IMAGE_REPO_URL="{{ public_image_repo_url | d('public_image_repo_url_not_set')}}"
export S3CMD_CONFIG=/dev/shm/{{ env_name }}/s3cfg
export SOPS_AGE_RECIPIENTS={{ sops_age_recipients | d('') }}
"""


def init_deployment_data():
    """ Generate shell variable data file."""
    pathlib.Path(f'/dev/shm/{os.environ["ENV_NAME"]}').mkdir(mode=0o700, parents=True, exist_ok=True)
    with open(f'/dev/shm/{os.environ["ENV_NAME"]}/deployment_data.sh', mode='w') as f:
        f.write(
            format_with_jinja2(
                DEPLOYMENT_DATA_TEMPLATE,
                dict(
                    env_name=os.environ['ENV_NAME'],
                    sops_age_recipients=pathlib.Path('/dev/shm/secret/age.public.key').read_text()
                )
            )
        )
        f.write('\n')
    print(f'Wrote deployment data to /dev/shm/{os.environ["ENV_NAME"]}/deployment_data.sh')


def render_file_templates():
    """ Render file templates defined in .env.yaml."""
    env_def = read_env_def()
    for file_def in env_def['files']:
        path = file_def.get('path', None)
        if not path:
            raise RuntimeError('No path specified for file')

        path = format_with_jinja2(path, env_def)
        kind = file_def.get('kind', 'file')
        mode = file_def.get('mode', 0o644)
        if isinstance(mode, str):
            mode = int(mode, 8)

        # process file content with variables defined in environment
        content = format_with_jinja2(file_def.get('content'), env_def)

        print('creating %s %s %o' % (kind, path, mode))
        if kind == 'file':
            if not pathlib.Path(path).exists():
                pathlib.Path(path).touch(mode=0o600)
            pathlib.Path(path).chmod(mode=0o600)
            with open(path, mode='w') as f:
                f.write(content)
            pathlib.Path(path).chmod(mode=mode)
        elif kind == 'directory':
            pathlib.Path(path).mkdir(parents=True, exist_ok=True, mode=mode)
            pathlib.Path(path).chmod(mode=mode)


if __name__ == '__main__':
    # setup age key for Sops
    init_age_secret_key()
    # generate environment specific environment variables file
    init_deployment_data()
    # process file templates defined in .env.yaml and .env_secrets.yaml
    render_file_templates()
