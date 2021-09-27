import logging
import os
import socket
import subprocess
from contextlib import closing
from time import sleep

import docker as docker

from admin import EXPLORER_SCRIPT_PATH, EXPLORERS_META_DATA_PATH
from admin.endpoints import read_json, get_all_names, get_schain_endpoint, write_json
from admin.logger import init_logger
from admin.nginx import add_schain_to_nginx

init_logger()
logger = logging.getLogger(__name__)
dutils = docker.DockerClient()


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


def run_explorer(schain_name, endpoint, ws_endpoint):
    explorer_port = get_free_port()
    db_port = get_db_port(schain_name)
    env = {
        'SCHAIN_NAME': schain_name,
        'PORT': str(explorer_port),
        'DB_PORT': str(db_port),
        'ENDPOINT': endpoint,
        'WS_ENDPOINT': ws_endpoint
    }
    logger.info(f'Running explorer with {env}')
    logger.info('=' * 100)
    subprocess.run(['bash', EXPLORER_SCRIPT_PATH], env={**env, **os.environ})
    logger.info('=' * 100)
    update_meta_data(schain_name, explorer_port, db_port, endpoint, ws_endpoint)
    add_schain_to_nginx(schain_name, f'http://127.0.0.1:{explorer_port}')
    restart_nginx()
    logger.info(f'sChain explorer is running on {schain_name}. subdomain')


def restart_nginx():
    nginx = dutils.containers.get('nginx')
    logger.info('Restarting nginx container...')
    nginx.restart()


def update_meta_data(schain_name, port, db_port, endpoint, ws_endpoint):
    logger.info(f'Updating meta data for {schain_name}')
    if not os.path.isfile(EXPLORERS_META_DATA_PATH):
        explorers = {}
    else:
        explorers = read_json(EXPLORERS_META_DATA_PATH)
    new_schain = {
        schain_name: {
            'port': port,
            'db_port': db_port,
            'endpoint': endpoint,
            'ws_endpoint': ws_endpoint
        }
    }
    explorers.update(new_schain)
    write_json(EXPLORERS_META_DATA_PATH, explorers)


def run_iteration():
    explorers = read_json(EXPLORERS_META_DATA_PATH)
    schains = get_all_names()
    for schain_name in schains:
        if schain_name not in explorers:
            endpoint = get_schain_endpoint(schain_name)
            ws_endpoint = get_schain_endpoint(schain_name, ws=True)
            run_explorer(schain_name, endpoint, ws_endpoint)


def main():
    if not os.path.isfile(EXPLORERS_META_DATA_PATH):
        with open(EXPLORERS_META_DATA_PATH, 'w') as f:
            f.write('{}')
    while True:
        logger.info('Running new iteration...')
        run_iteration()
        sleep_time = 600
        logger.info(f'Sleeping {sleep_time}s')
        sleep(sleep_time)


main()
