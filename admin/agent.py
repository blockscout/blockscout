import logging
import os
import subprocess
from time import sleep

from admin import EXPLORER_SCRIPT_PATH, EXPLORERS_META_DATA_PATH
from admin.containers import (get_free_port, get_db_port, restart_nginx,
                              is_explorer_found, is_explorer_running, remove_explorer)
from admin.endpoints import read_json, get_all_names, get_schain_endpoint, write_json
from admin.logger import init_logger
from admin.nginx import regenerate_nginx_config

init_logger()
logger = logging.getLogger(__name__)


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
    regenerate_nginx_config()
    restart_nginx()
    logger.info(f'sChain explorer is running on {schain_name}. subdomain')


def run_explorer_for_schain(schain_name):
    endpoint = get_schain_endpoint(schain_name)
    ws_endpoint = get_schain_endpoint(schain_name, ws=True)
    run_explorer(schain_name, endpoint, ws_endpoint)


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
        if schain_name not in explorers or not is_explorer_found(schain_name):
            endpoint = get_schain_endpoint(schain_name)
            ws_endpoint = get_schain_endpoint(schain_name, ws=True)
            run_explorer(schain_name, endpoint, ws_endpoint)
        if not is_explorer_running(schain_name):
            logger.warning(f'Blockscout is not working for {schain_name}. Recreating...')
            remove_explorer(schain_name)
            run_explorer_for_schain(schain_name)


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
