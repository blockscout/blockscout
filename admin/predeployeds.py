import json
import logging
import os

from etherbase_predeployed.etherbase_upgradeable_generator import EtherbaseUpgradeableGenerator
from marionette_predeployed.marionette_generator import MarionetteGenerator
from web3 import Web3, HTTPProvider

from admin import (
    SCHAIN_CONFIG_DIR_PATH, MAINNET_IMA_ABI_FILEPATH, PROXY_ADMIN_PREDEPLOYED_ADDRESS, BASE_ADDRESS,
    ETHERBASE_ALLOC, SCHAIN_OWNER_ALLOC, NODE_OWNER_ALLOC, ZERO_ADDRESS, ENDPOINT, ABI_FILEPATH,
    HOST_SCHAIN_CONFIG_DIR_PATH, EXPLORERS_META_DATA_PATH
)
from admin.endpoints import read_json, schain_name_to_id

from etherbase_predeployed import (
    UpgradeableEtherbaseUpgradeableGenerator, ETHERBASE_ADDRESS, ETHERBASE_IMPLEMENTATION_ADDRESS
)
from marionette_predeployed import (
    UpgradeableMarionetteGenerator, MARIONETTE_ADDRESS, MARIONETTE_IMPLEMENTATION_ADDRESS
)
from filestorage_predeployed import (
    UpgradeableFileStorageGenerator, FILESTORAGE_ADDRESS, FILESTORAGE_IMPLEMENTATION_ADDRESS,
    FileStorageGenerator
)
from config_controller_predeployed import (
    UpgradeableConfigControllerGenerator,
    CONFIG_CONTROLLER_ADDRESS,
    CONFIG_CONTROLLER_IMPLEMENTATION_ADDRESS, ConfigControllerGenerator
)
from multisigwallet_predeployed import MultiSigWalletGenerator, MULTISIGWALLET_ADDRESS
from context_predeployed import ContextGenerator, CONTEXT_ADDRESS
from predeployed_generator.openzeppelin.proxy_admin_generator import ProxyAdminGenerator
from ima_predeployed.generator import generate_contracts, generate_meta

logger = logging.getLogger(__name__)


def generate_config(schain_name):
    config_path = os.path.join(SCHAIN_CONFIG_DIR_PATH, f'{schain_name}.json')
    if not os.path.exists(config_path):
        logger.info(f'Generating config for {schain_name}')
        verification_data = generate_verify_data()
        addresses = verification_data.keys()
        config = {
            'alloc': {
                **fetch_predeployed_info(schain_name, addresses),
                # **generate_owner_accounts(schain_name)
            },
            'verify': verification_data
        }
        with open(config_path, 'w') as f:
            f.write(json.dumps(config, indent=4))
    host_config_path = os.path.join(HOST_SCHAIN_CONFIG_DIR_PATH, f'{schain_name}.json')
    return host_config_path


def get_ima_contracts():
    mainnet_ima_abi = read_json(MAINNET_IMA_ABI_FILEPATH)
    return generate_contracts(
        owner_address=BASE_ADDRESS,
        schain_name='schain',
        contracts_on_mainnet=mainnet_ima_abi
    )


def generate_owner_accounts(schain_name):
    schain_info = get_schain_info(schain_name)
    accounts = {}
    if schain_info['generation'] == 0:
        add_to_accounts(accounts, schain_info['mainnetOwner'], SCHAIN_OWNER_ALLOC)
    if schain_info['generation'] == 1:
        add_to_accounts(accounts, get_schain_originator(schain_info), SCHAIN_OWNER_ALLOC)
    for wallet in schain_info['nodes']:
        add_to_accounts(accounts, wallet, NODE_OWNER_ALLOC)
    return accounts


def add_to_accounts(accounts, address, balance=0, nonce=0, code=""):
    fixed_address = Web3.toChecksumAddress(address)
    account = {
        'balance': str(balance),
    }
    if code:
        account.update({
            'code': code,
            'nonce': hex(nonce),
            'storage': {}
        })
    accounts[fixed_address] = account


def generate_verify_data():
    raw_verification_dict = {
        PROXY_ADMIN_PREDEPLOYED_ADDRESS: ProxyAdminGenerator().get_meta(),
        CONTEXT_ADDRESS: ContextGenerator().get_meta(),
        CONFIG_CONTROLLER_ADDRESS: UpgradeableConfigControllerGenerator().get_meta(),
        CONFIG_CONTROLLER_IMPLEMENTATION_ADDRESS: ConfigControllerGenerator().get_meta(),
        MARIONETTE_ADDRESS: UpgradeableMarionetteGenerator().get_meta(),
        MARIONETTE_IMPLEMENTATION_ADDRESS: MarionetteGenerator().get_meta(),
        ETHERBASE_ADDRESS: UpgradeableEtherbaseUpgradeableGenerator().get_meta(),
        ETHERBASE_IMPLEMENTATION_ADDRESS: EtherbaseUpgradeableGenerator().get_meta(),
        MULTISIGWALLET_ADDRESS: MultiSigWalletGenerator().get_meta(),
        FILESTORAGE_ADDRESS: UpgradeableFileStorageGenerator().get_meta(),
        FILESTORAGE_IMPLEMENTATION_ADDRESS: FileStorageGenerator().get_meta(),
        **generate_meta()
    }
    return {
        Web3.toChecksumAddress(k): raw_verification_dict[k]
        for k in raw_verification_dict
    }


def get_schain_originator(schain: dict):
    if schain['originator'] == ZERO_ADDRESS:
        return schain['mainnetOwner']
    return schain['originator']


def fetch_predeployed_info(schain_name, contract_addresses):
    predeployed_contracts = {}
    with open(EXPLORERS_META_DATA_PATH) as explorers:
        data = json.loads(explorers.read())
        schain_endpoint = data[schain_name]['endpoint']
    provider = HTTPProvider(schain_endpoint)
    web3 = Web3(provider)
    for address in contract_addresses:
        code = web3.eth.get_code(address).hex()
        if address == ETHERBASE_ADDRESS:
            add_to_accounts(predeployed_contracts, address, balance=ETHERBASE_ALLOC, code=code)
        else:
            add_to_accounts(predeployed_contracts, address, code=code)
    return predeployed_contracts


def get_schain_info(schain_name):
    provider = HTTPProvider(ENDPOINT)
    web3 = Web3(provider)
    sm_abi = read_json(ABI_FILEPATH)
    schains_internal_contract = web3.eth.contract(address=sm_abi['schains_internal_address'],
                                                  abi=sm_abi['schains_internal_abi'])
    nodes_contract = web3.eth.contract(address=sm_abi['nodes_address'], abi=sm_abi['nodes_abi'])

    schain_id = bytes.fromhex(schain_name_to_id(schain_name)[2:])
    schain_info = schains_internal_contract.functions.schains(schain_id).call()
    node_ids = schains_internal_contract.functions.getNodesInGroup(schain_id).call()
    wallets = []
    for node_id in node_ids:
        wallets.append(nodes_contract.functions.getNodeAddress(node_id).call())
    return {
        'mainnetOwner': schain_info[1],
        'originator': schain_info[10],
        'generation': schain_info[9],
        'nodes': wallets
    }


generate_config('fancy-rasalhague')