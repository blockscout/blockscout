import os
import logging
import json
import socket
from enum import Enum

from web3 import Web3, HTTPProvider, WebsocketProvider
from Crypto.Hash import keccak

from admin import ENDPOINT, ABI_FILEPATH, PROXY_DOMAIN_NAME

logger = logging.getLogger(__name__)


RESULTS_PATH = "/tmp/chains.json"
SCHAIN_FIRST_INDEX = os.environ.get('FIRST_SCHAIN_ID')
SCHAIN_LAST_INDEX = os.environ.get('LAST_SCHAIN_ID')

PORTS_PER_SCHAIN = 64


class SkaledPorts(Enum):
    PROPOSAL = 0
    CATCHUP = 1
    WS_JSON = 2
    HTTP_JSON = 3
    BINARY_CONSENSUS = 4
    ZMQ_BROADCAST = 5
    IMA_MONITORING = 6
    WSS_JSON = 7
    HTTPS_JSON = 8
    INFO_HTTP_JSON = 9


def read_json(path, mode='r'):
    with open(path, mode=mode, encoding='utf-8') as data_file:
        return json.load(data_file)


def write_json(path, content):
    with open(path, 'w') as outfile:
        json.dump(content, outfile, indent=4)


def schain_name_to_id(name):
    keccak_hash = keccak.new(data=name.encode("utf8"), digest_bits=256)
    return '0x' + keccak_hash.hexdigest()


def ip_from_bytes(bytes):
    return socket.inet_ntoa(bytes)


def get_schain_index_in_node(schain_id, schains_ids_on_node):
    for index, schain_id_on_node in enumerate(schains_ids_on_node):
        if schain_id == schain_id_on_node:
            return index
    raise Exception(f'sChain {schain_id} is not found in the list: {schains_ids_on_node}')


def get_schain_base_port_on_node(schain_id, schains_ids_on_node, node_base_port):
    schain_index = get_schain_index_in_node(schain_id, schains_ids_on_node)
    return calc_schain_base_port(node_base_port, schain_index)


def calc_schain_base_port(node_base_port, schain_index):
    return node_base_port + schain_index * PORTS_PER_SCHAIN


def calc_ports(schain_base_port):
    return {
        'httpRpcPort': schain_base_port + SkaledPorts.HTTP_JSON.value,
        'httpsRpcPort': schain_base_port + SkaledPorts.HTTPS_JSON.value,
        'wsRpcPort': schain_base_port + SkaledPorts.WS_JSON.value,
        'wssRpcPort': schain_base_port + SkaledPorts.WSS_JSON.value,
        'infoHttpRpcPort': schain_base_port + SkaledPorts.INFO_HTTP_JSON.value
    }


def compose_endpoints(node_dict, endpoint_type):
    node_dict[f'http_endpoint_{endpoint_type}'] = f'http://{node_dict[endpoint_type]}:{node_dict["httpRpcPort"]}'
    node_dict[f'https_endpoint_{endpoint_type}'] = f'https://{node_dict[endpoint_type]}:{node_dict["httpsRpcPort"]}'
    node_dict[f'ws_endpoint_{endpoint_type}'] = f'ws://{node_dict[endpoint_type]}:{node_dict["wsRpcPort"]}'
    node_dict[f'wss_endpoint_{endpoint_type}'] = f'wss://{node_dict[endpoint_type]}:{node_dict["wssRpcPort"]}'
    node_dict[f'info_http_endpoint_{endpoint_type}'] = f'http://{node_dict[endpoint_type]}:{node_dict["infoHttpRpcPort"]}'


def endpoints_for_schain(schains_internal_contract, nodes_contract, schain_id):
    node_ids = schains_internal_contract.functions.getNodesInGroup(schain_id).call()
    nodes = []
    for node_id in node_ids:
        node = nodes_contract.functions.nodes(node_id).call()
        node_dict = {
            'id': node_id,
            'name': node[0],
            'ip': ip_from_bytes(node[1]),
            'base_port': node[3],
            'domain': nodes_contract.functions.getNodeDomainName(node_id).call()
        }
        schain_ids = schains_internal_contract.functions.getSchainIdsForNode(node_id).call()
        node_dict['schain_base_port'] = get_schain_base_port_on_node(schain_id, schain_ids, node_dict['base_port'])
        node_dict.update(calc_ports(node_dict['schain_base_port']))

        compose_endpoints(node_dict, endpoint_type='ip')
        compose_endpoints(node_dict, endpoint_type='domain')

        nodes.append(node_dict)
    schain = schains_internal_contract.functions.schains(schain_id).call()
    return {
        'schain': schain,
        'schain_id': schain_name_to_id(schain[0])[:15],
        'nodes': nodes
    }


def get_all_names():
    provider = HTTPProvider(ENDPOINT)
    web3 = Web3(provider)
    sm_abi = read_json(ABI_FILEPATH)

    schains_internal_contract = web3.eth.contract(address=sm_abi['schains_internal_address'], abi=sm_abi['schains_internal_abi'])
    schain_ids = schains_internal_contract.functions.getSchains().call()
    first = SCHAIN_FIRST_INDEX if SCHAIN_FIRST_INDEX else 0
    last = SCHAIN_LAST_INDEX if SCHAIN_LAST_INDEX else len(schain_ids)
    return [schains_internal_contract.functions.schains(id).call()[0] for id in schain_ids[first:last]]


def is_dkg_passed(schain_name):
    provider = HTTPProvider(ENDPOINT)
    web3 = Web3(provider)
    sm_abi = read_json(ABI_FILEPATH)
    dkg_contract = web3.eth.contract(address=sm_abi['skale_d_k_g_address'],
                                                  abi=sm_abi['skale_d_k_g_abi'])
    group_id = web3.keccak(text=schain_name)
    return dkg_contract.functions.isLastDKGSuccessful(group_id).call()


def check_endpoint(endpoint, ws=False):
    try:
        if ws:
            w3 = Web3(WebsocketProvider(endpoint))
        else:
            w3 = Web3(HTTPProvider(endpoint))
        w3.eth.get_block_number()
        return True
    except Exception as e:
        logger.warning(f'Check {endpoint} endpoint fail with {e}')
        return False


def get_proxy_endpoint(schain_name, ws=False):
    if ws:
        return f'ws://{PROXY_DOMAIN_NAME}/v1/ws/{schain_name}'
    return f'https://{PROXY_DOMAIN_NAME}/v1/{schain_name}'


def get_schain_endpoint(schain_name, ws=False):
    proxy = get_proxy_endpoint(schain_name, ws)
    if check_endpoint(proxy, ws):
        return proxy

    provider = HTTPProvider(ENDPOINT)
    web3 = Web3(provider)
    sm_abi = read_json(ABI_FILEPATH)
    schains_internal_contract = web3.eth.contract(address=sm_abi['schains_internal_address'], abi=sm_abi['schains_internal_abi'])
    nodes_contract = web3.eth.contract(address=sm_abi['nodes_address'], abi=sm_abi['nodes_abi'])
    schain_id = bytes.fromhex(schain_name_to_id(schain_name)[2:])
    endpoints = endpoints_for_schain(schains_internal_contract, nodes_contract, schain_id)
    for node in endpoints['nodes']:
        if ws:
            endpoint = node['ws_endpoint_domain']
        else:
            endpoint = node['https_endpoint_domain']
        if check_endpoint(endpoint, ws):
            return endpoint
