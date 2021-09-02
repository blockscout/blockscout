import os
import socket
import subprocess
from contextlib import closing

import docker as docker

NGINX_CONFIG_PATH = ''
NGINX_TEMP_CONFIG_PATH = ''
DIR_PATH = os.path.dirname(os.path.realpath(__file__))
PROJECT_PATH = os.path.join(DIR_PATH, os.pardir)
EXPLORER_SCRIPT_PATH = os.path.join(PROJECT_PATH, 'docker', 'run_schain_explorer.sh')

dutils = docker.DockerClient()


def update_and_restart():
    pass


def is_explorer_exist(schain_name):
    pass


def is_database_exist(schain_name):
    pass


def get_free_port():
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(('', 0))
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        return s.getsockname()[1]


def get_db_port(schain_name):
    try:
        db = dutils.containers.get(f'postgres_{schain_name}')
        return get_container_host_port(db)
    except docker.errors.NotFound:
        return get_free_port()


def get_container_host_port(container):
    ports = list(container.attrs['NetworkSettings']['Ports'].values())
    return ports[0][0]['HostPort']


def run_explorer(schain_name, endpoint):
    explorer_port = get_free_port()
    db_port = get_db_port(schain_name)
    env = {
        'SCHAIN_NAME': schain_name,
        'PORT': str(explorer_port),
        'DB_PORT': str(db_port),
        'ENDPOINT': endpoint
    }
    print(f'Running explorer for {schain_name}, port: {explorer_port}, db port: {db_port}')
    subprocess.run(['bash', EXPLORER_SCRIPT_PATH], env={**env, **os.environ})

