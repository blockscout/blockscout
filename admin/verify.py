import logging
from os.path import join
import requests
import json

from web3 import Web3

from admin import SCHAIN_CONFIG_DIR_PATH, EXPLORERS_META_DATA_PATH
from admin.endpoints import read_json, write_json

logger = logging.getLogger(__name__)


def verify(schain_name):
    logger.info(f'Verifying contracts for {schain_name}')
    config = read_json(join(SCHAIN_CONFIG_DIR_PATH, f'{schain_name}.json'))
    j = config['verify']
    contracts = get_contract_list(schain_name)
    for verifying_address in j.keys():
        status = contracts.get(verifying_address)
        if status is False:
            logging.info(f'Verifying {verifying_address} contract')
            contract_meta = j[verifying_address]
            contract = {
                'contractaddress': verifying_address,
                'contractname': contract_meta['name'],
                'compilerversion': f'v{contract_meta["solcLongVersion"]}',
                'sourceCode': json.dumps(contract_meta['input'])
            }
            send_verify_request(schain_name, contract)
    post_contracts = get_contract_list(schain_name)
    all_verified = True
    for verifying_address in j.keys():
        if post_contracts.get(verifying_address) is not True:
            all_verified = False
    if all_verified:
        data = read_json(EXPLORERS_META_DATA_PATH)
        data[schain_name]['contracts_verified'] = True
        write_json(EXPLORERS_META_DATA_PATH, data)


def get_contract_list(schain_name):
    data = read_json(EXPLORERS_META_DATA_PATH)
    schain_explorer_endpoint = f'http://127.0.0.1:{data[schain_name]["port"]}'
    headers = {'content-type': 'application/json'}
    addresses = {}
    try:
        result = requests.get(
            f'{schain_explorer_endpoint}/api?module=contract&action=listcontracts',
            headers=headers
        ).json()['result']
        addresses = {
            Web3.toChecksumAddress(contract['Address']): contract['ABI'] != 'Contract source code not verified'
            for contract in result
        }
    except requests.exceptions.ConnectionError as e:
        logger.warning(f'get_contract_list failed with {e}')
    return addresses


def get_veify_url(schain_name):
    data = read_json(EXPLORERS_META_DATA_PATH)
    schain_explorer_endpoint = f'http://127.0.0.1:{data[schain_name]["port"]}'
    return f'{schain_explorer_endpoint}/api?module=contract&action=verifysourcecode&codeformat=solidity-standard-json-input'


def send_verify_request(schain_name, verification_data):
    headers = {'content-type': 'application/json'}
    try:
        return requests.post(
            get_veify_url(schain_name),
            data=json.dumps(verification_data),
            headers=headers
        ).json()
    except requests.exceptions.ConnectionError as e:
        logger.warning(f'verifying_address failer with {e}')
