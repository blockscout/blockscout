import os
from admin import (NGINX_CONFIG_PATH, EXPLORERS_META_DATA_PATH, SSL_CRT_PATH,
                   SSL_KEY_PATH)
import crossplane

from admin.endpoints import read_json


def generate_schain_nginx_config(schain_name, explorer_endpoint, ssl=False):
    config = generate_base_nginx_config(schain_name, explorer_endpoint)
    if ssl:
        ssl_block = [
                {
                    "directive": "listen",
                    "args": [
                        '443',
                        'ssl'
                    ]
                },
                {
                    "directive": "ssl_certificate",
                    "args": [
                        '/data/server.crt'
                    ]
                },
                {
                    "directive": "ssl_certificate_key",
                    "args": [
                        '/data/server.key'
                    ]
                }
        ]
        config['block'] = ssl_block + config['block']
    return config


def generate_base_nginx_config(schain_name, explorer_endpoint):
    return {
        "directive": "server",
        "args": [],
        "block": [
            {
                "directive": "listen",
                "args": [
                    '80'
                ]
            },
            {
                "directive": "server_name",
                "args": [
                    f"{schain_name}.*"
                ]
            },
            {
                "directive": "location",
                "args": [
                    "/socket"
                ],
                "block":[
                    {
                        "directive": "proxy_http_version",
                        "args": [
                            '1.1'
                        ]
                    },
                    {
                        "directive": "proxy_set_header",
                        "args": [
                            'Upgrade', '$http_upgrade'
                        ]
                    },
                    {
                        "directive": "proxy_set_header",
                        "args": [
                            'Connection', "upgrade"
                        ]
                    },
                    {
                        "directive": "proxy_pass",
                        "args": [
                            explorer_endpoint
                        ]
                    }
                ]
            },
            {
                "directive": "location",
                "args": [
                    "/"
                ],
                "block":[
                    {
                        "directive": "proxy_pass",
                        "args": [
                            explorer_endpoint
                        ]
                    }
                ]
            }
        ]
    }


def regenerate_nginx_config():
    explorers = read_json(EXPLORERS_META_DATA_PATH)
    nginx_cfg = []
    for schain_name in explorers:
        explorer_endpoint = f'http://127.0.0.1:{explorers[schain_name]["port"]}'
        if os.path.isfile(SSL_CRT_PATH) and os.path.isfile(SSL_KEY_PATH):
            schain_config = generate_schain_nginx_config(schain_name, explorer_endpoint, ssl=True)
        else:
            schain_config = generate_schain_nginx_config(schain_name, explorer_endpoint)
        nginx_cfg.append(schain_config)
    formatted_config = crossplane.build(nginx_cfg)
    with open(NGINX_CONFIG_PATH, 'w') as f:
        f.write(formatted_config)
