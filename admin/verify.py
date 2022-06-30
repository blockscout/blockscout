import os.path
import requests
import json
from admin import SCHAIN_CONFIG_DIR_PATH, EXPLORERS_META_DATA_PATH


def verify(schain_name=None):
    with open(os.path.join(SCHAIN_CONFIG_DIR_PATH, f'{schain_name}.json')) as file:
        j = json.loads(file.read())['verify']

        for verifying_address in j.keys():
            contract_meta = j[verifying_address]
            contract = {
                'contractaddress': verifying_address,
                'contractname': contract_meta['name'],
                'compilerversion': f'v{contract_meta["solcLongVersion"]}',
                'sourceCode': json.dumps(contract_meta['input'])
            }
            send_verify_request(schain_name, contract)


def get_veify_url(schain_name):
    with open(EXPLORERS_META_DATA_PATH) as explorers:
        data = json.loads(explorers.read())
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
    except:
        pass
