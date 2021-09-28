import logging
import docker
import socket
from contextlib import closing

from admin.logger import init_logger

init_logger()
logger = logging.getLogger(__name__)
dutils = docker.DockerClient()


CONTAINER_NOT_FOUND = 'not_found'
EXITED_STATUS = 'exited'
CREATED_STATUS = 'created'
RUNNING_STATUS = 'running'


def is_explorer_found(schain_name):
    container_name = f'blockscout_{schain_name}'
    return is_container_exists(container_name)


def is_container_exists(name: str) -> bool:
    try:
        dutils.containers.get(name)
    except docker.errors.NotFound:
        return False
    return True


def get_info(container_id: str) -> dict:
    container_info = {}
    try:
        container = dutils.containers.get(container_id)
        container_info['status'] = container.status
    except docker.errors.NotFound:
        logger.warning(
            f'Can not get info - no such container: {container_id}')
        container_info['status'] = CONTAINER_NOT_FOUND
    return container_info


def get_db_port(schain_name):
    try:
        db = dutils.containers.get(f'postgres_{schain_name}')
        return get_container_host_port(db)
    except docker.errors.NotFound:
        return get_free_port()


def get_container_host_port(container):
    ports = list(container.attrs['NetworkSettings']['Ports'].values())
    return ports[0][0]['HostPort']


def restart_nginx():
    nginx = dutils.containers.get('nginx')
    logger.info('Restarting nginx container...')
    nginx.restart()


def get_free_port():
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(('', 0))
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        return s.getsockname()[1]