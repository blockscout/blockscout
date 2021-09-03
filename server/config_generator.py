import os
import socket
import subprocess
from contextlib import closing
from time import sleep

import docker as docker

from server import EXPLORER_SCRIPT_PATH, EXPLORERS_META_DATA_PATH
from server.endpoints import read_json, get_all_names, get_schain_endpoint, write_json

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


def add_explorer_meta(schain_name):
    pass


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
    update_meta_data(schain_name, explorer_port, db_port, endpoint)


def update_meta_data(schain_name, port, db_port, endpoint):
    if not os.path.isfile(EXPLORERS_META_DATA_PATH):
        explorers = {}
    else:
        explorers = read_json(EXPLORERS_META_DATA_PATH)
    new_schain = {
        schain_name: {
            'port': port,
            'db_port': db_port,
            'endpoint': endpoint
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
            run_explorer(schain_name, endpoint)


def main():
    if not os.path.isfile(EXPLORERS_META_DATA_PATH):
        with open(EXPLORERS_META_DATA_PATH, 'w') as f:
            f.write('{}')
    while True:
        print('Running new iteration...')
        run_iteration()
        sleep_time = 600
        print(f'Sleeping {sleep_time}s')
        sleep(sleep_time)


main()
