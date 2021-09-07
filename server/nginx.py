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
                    f"{schain_name}.localhost"
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


def delete_keys_from_dict(dict_del, lst_keys):
    for k in lst_keys:
        try:
            del dict_del[k]
        except KeyError:
            pass
    for v in dict_del.values():
        if isinstance(v, dict):
            delete_keys_from_dict(v, lst_keys)

    return dict_del


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
