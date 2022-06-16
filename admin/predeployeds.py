import json
import logging
import os

from web3 import Web3, HTTPProvider

from admin import SCHAIN_CONFIG_DIR_PATH, MAINNET_IMA_ABI_FILEPATH, PROXY_ADMIN_PREDEPLOYED_ADDRESS, empty_address, \
    ETHERBASE_ALLOC, SCHAIN_OWNER_ALLOC, NODE_OWNER_ALLOC, ZERO_ADDRESS, ENDPOINT, ABI_FILEPATH, \
    HOST_SCHAIN_CONFIG_DIR_PATH
from admin.endpoints import read_json, schain_name_to_id

from etherbase_predeployed import (
    UpgradeableEtherbaseUpgradeableGenerator, ETHERBASE_ADDRESS, ETHERBASE_IMPLEMENTATION_ADDRESS
)
from marionette_predeployed import (
    UpgradeableMarionetteGenerator, MARIONETTE_ADDRESS, MARIONETTE_IMPLEMENTATION_ADDRESS
)
from filestorage_predeployed import (
    UpgradeableFileStorageGenerator, FILESTORAGE_ADDRESS, FILESTORAGE_IMPLEMENTATION_ADDRESS
)
from config_controller_predeployed import (
    UpgradeableConfigControllerGenerator,
    CONFIG_CONTROLLER_ADDRESS,
    CONFIG_CONTROLLER_IMPLEMENTATION_ADDRESS
)
from multisigwallet_predeployed import MultiSigWalletGenerator, MULTISIGWALLET_ADDRESS
from predeployed_generator.openzeppelin.proxy_admin_generator import ProxyAdminGenerator
from ima_predeployed.generator import generate_contracts

logger = logging.getLogger(__name__)


def generate_config(schain_name):
    config_path = os.path.join(SCHAIN_CONFIG_DIR_PATH, f'{schain_name}.json')
    if not os.path.exists(config_path):
        logger.info(f'Generating config for {schain_name}')
        config = {
            'alloc': {
                **get_predeployed_data(),
                **get_ima_contracts(),
                **generate_owner_accounts(schain_name)
            }
        }
        with open(config_path, 'w') as f:
            f.write(json.dumps(config, indent=4))
    host_config_path = os.path.join(HOST_SCHAIN_CONFIG_DIR_PATH, f'{schain_name}.json')
    return host_config_path


def get_predeployed_data():
    proxy_admin_generator = ProxyAdminGenerator()
    proxy_admin_predeployed = proxy_admin_generator.generate_allocation(
        contract_address=PROXY_ADMIN_PREDEPLOYED_ADDRESS,
        owner_address=empty_address
    )

    etherbase_generator = UpgradeableEtherbaseUpgradeableGenerator()
    etherbase_predeployed = etherbase_generator.generate_allocation(
        contract_address=ETHERBASE_ADDRESS,
        implementation_address=ETHERBASE_IMPLEMENTATION_ADDRESS,
        schain_owner=empty_address,
        ether_managers=[empty_address],
        proxy_admin_address=PROXY_ADMIN_PREDEPLOYED_ADDRESS,
        balance=ETHERBASE_ALLOC
    )

    marionette_generator = UpgradeableMarionetteGenerator()
    marionette_predeployed = marionette_generator.generate_allocation(
        contract_address=MARIONETTE_ADDRESS,
        implementation_address=MARIONETTE_IMPLEMENTATION_ADDRESS,
        proxy_admin_address=PROXY_ADMIN_PREDEPLOYED_ADDRESS,
        schain_owner=empty_address,
        marionette=empty_address,
        owner=MULTISIGWALLET_ADDRESS,
        ima=empty_address,
    )

    filestorage_generator = UpgradeableFileStorageGenerator()
    filestorage_predeployed = filestorage_generator.generate_allocation(
        contract_address=FILESTORAGE_ADDRESS,
        implementation_address=FILESTORAGE_IMPLEMENTATION_ADDRESS,
        schain_owner=empty_address,
        proxy_admin_address=PROXY_ADMIN_PREDEPLOYED_ADDRESS,
        allocated_storage=0
    )

    config_generator = UpgradeableConfigControllerGenerator()
    config_controller_predeployed = config_generator.generate_allocation(
        contract_address=CONFIG_CONTROLLER_ADDRESS,
        implementation_address=CONFIG_CONTROLLER_IMPLEMENTATION_ADDRESS,
        schain_owner=empty_address,
        proxy_admin_address=PROXY_ADMIN_PREDEPLOYED_ADDRESS
    )

    multisigwallet_generator = MultiSigWalletGenerator()
    multisigwallet_predeployed = multisigwallet_generator.generate_allocation(
        contract_address=MULTISIGWALLET_ADDRESS,
        originator_addresses=[empty_address]
    )

    return {
        **proxy_admin_predeployed,
        **etherbase_predeployed,
        **marionette_predeployed,
        **filestorage_predeployed,
        **config_controller_predeployed,
        **multisigwallet_predeployed
    }


def get_ima_contracts():
    mainnet_ima_abi = read_json(MAINNET_IMA_ABI_FILEPATH)
    return generate_contracts(
        owner_address=empty_address,
        schain_name='schain',
        contracts_on_mainnet=mainnet_ima_abi
    )


def generate_owner_accounts(schain_name):
    schain_info = get_schain_info(schain_name)
    accounts = {}
    if schain_info['generation'] == 0:
        add_to_accounts(accounts, schain_info['owner'], SCHAIN_OWNER_ALLOC)
    if schain_info['generation'] == 1:
        add_to_accounts(accounts, get_schain_originator(schain_info), SCHAIN_OWNER_ALLOC)
    for wallet in schain_info['nodes']:
        add_to_accounts(accounts, wallet, NODE_OWNER_ALLOC)
    return accounts


def add_to_accounts(accounts, address, balance):
    fixed_address = Web3.toChecksumAddress(address)
    accounts[fixed_address] = {
        'balance': str(balance)
    }


def get_schain_originator(schain: dict):
    if schain['originator'] == ZERO_ADDRESS:
        return schain['mainnetOwner']
    return schain['originator']


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