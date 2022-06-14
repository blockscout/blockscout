import os
from admin import SCHAIN_CONFIG_DIR_PATH, MAINNET_IMA_ABI_FILEPATH
from admin.endpoints import read_json

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

PROXY_ADMIN_PREDEPLOYED_ADDRESS = '0xD1000000000000000000000000000000000000D1'
empty_address = '0x0000000000000000000000000000000000000001'


def generate_config(schain_name):
    config_path = os.path.join(SCHAIN_CONFIG_DIR_PATH, f'{schain_name}.json')
    if not os.path.exists(config_path):
        pass


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
        balance=0
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
