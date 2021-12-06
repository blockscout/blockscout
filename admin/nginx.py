from admin import (NGINX_CONFIG_PATH, EXPLORERS_META_DATA_PATH, SSL_CRT_PATH,
                   SSL_KEY_PATH, SSL_DIR_PATH)
import crossplane

from admin.endpoints import read_json


def generate_ssl_nginx_config(schain_name, explorer_endpoint):
    base_cfg = generate_schain_base_nginx_config(schain_name, explorer_endpoint)
    ssl_block = [
            {
                "directive": "listen",
                "args": [
                    '443'
                ]
            },
            {
                "directive": "ssl_certificate",
                "args": [
                    SSL_CRT_PATH
                ]
            },
            {
                "directive": "ssl_certificate_key",
                "args": [
                    SSL_KEY_PATH
                ]
            },
            {
                "directive": "ssl_verify_client",
                "args": [
                    "off"
                ]
            }
    ]
    base_cfg['block'] = ssl_block + base_cfg['block']
    return base_cfg


def generate_schain_base_nginx_config(schain_name, explorer_endpoint):
    return {
        "directive": "server",
        "args": [],
        "block": [
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
        schain_config = generate_schain_base_nginx_config(schain_name, explorer_endpoint)
        nginx_cfg.append(schain_config)
        if SSL_DIR_PATH:
            ssl_schain_config = generate_ssl_nginx_config(schain_name, explorer_endpoint)
            nginx_cfg.append(ssl_schain_config)
    formatted_config = crossplane.build(nginx_cfg)
    with open(NGINX_CONFIG_PATH, 'w') as f:
        f.write(formatted_config)
