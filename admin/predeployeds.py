import os
from admin import SCHAIN_CONFIG_DIR_PATH


def generate_config(schain_name):
    config_path = os.path.join(SCHAIN_CONFIG_DIR_PATH, f'{schain_name}.json')
    if not os.path.exists(config_path):
        pass