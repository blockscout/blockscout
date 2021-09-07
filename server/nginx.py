from server import NGINX_CONFIG_PATH
import crossplane


def generate_schain_config(schain_name, explorer_endpoint):
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


def parse_nginx_conf(cfg_path):
    parsed_cfg = crossplane.parse(cfg_path, check_ctx=False)
    return parsed_cfg['config'][0]['parsed']


def add_schain_to_nginx(schain_name, explorer_endpoint):
    nginx_cfg = parse_nginx_conf(NGINX_CONFIG_PATH)
    schain_config = generate_schain_config(schain_name, explorer_endpoint)
    nginx_cfg.append(schain_config)
    formatted_config = crossplane.build(nginx_cfg)
    with open(NGINX_CONFIG_PATH, 'w') as f:
        f.write(formatted_config)
