import pkg_resources
import requests
import json
from context_predeployed import CONTEXT_ADDRESS


def verify(schain_name=None):
    r = pkg_resources.resource_filename('context_predeployed', 'artifacts/Context.json')
    with open(r) as file:
        j = json.loads(file.read())

        contract = {
            'addressHash': CONTEXT_ADDRESS,
            'name': j['contractName'],
            'compilerVersion': f'v{j["compiler"]["version"]}',
            'contractSourceCode': j['source']
        }
        if j['optimizer']['enabled']:
            contract.update({
                'optimizer': True,
                'optimizationRuns': j['optimizer']['enabled']['runs']
            })
        else:
            contract.update({
                'optimizer': False
            })
        print(send_verify_request(schain_name, contract))
    pass


def get_veify_url(schain_name):
    schain_explorer_endpoint = ''
    return f'{schain_explorer_endpoint}/api?module=contract&action=verify'


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

