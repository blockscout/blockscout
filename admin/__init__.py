import os

DIR_PATH = os.path.dirname(os.path.realpath(__file__))
PROJECT_PATH = os.path.join(DIR_PATH, os.pardir)
EXPLORER_SCRIPT_PATH = os.path.join(PROJECT_PATH, 'docker', 'run_schain_explorer.sh')
SERVER_DATA_DIR = os.path.join(DIR_PATH, 'data')
ABI_FILEPATH = os.path.join(SERVER_DATA_DIR, 'abi.json')
MAINNET_IMA_ABI_FILEPATH = os.path.join(SERVER_DATA_DIR, 'ima.json')
EXPLORERS_META_DATA_PATH = os.path.join(SERVER_DATA_DIR, 'meta.json')
SCHAIN_CONFIG_DIR_PATH = os.path.join(SERVER_DATA_DIR, 'configs')

NGINX_CONFIG_PATH = os.path.join(SERVER_DATA_DIR, 'nginx.conf')
NGINX_TEMP_CONFIG_PATH = os.path.join(SERVER_DATA_DIR, 'nginx.temp.conf')

ENDPOINT = os.environ['ETH_ENDPOINT']
PROXY_DOMAIN_NAME = os.environ.get('PROXY_DOMAIN')

SSL_DIR_PATH = os.path.join(SERVER_DATA_DIR, 'certs')
SSL_CRT_PATH = os.path.join(SSL_DIR_PATH, 'server.crt')
SSL_KEY_PATH = os.path.join(SSL_DIR_PATH, 'server.key')

assert os.path.isfile(ABI_FILEPATH), "ABI not found"
