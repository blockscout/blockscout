import json
import sys

import psycopg2
from psycopg2.extras import execute_values
from web3 import HTTPProvider, Web3
from admin import EXPLORERS_META_DATA_PATH


def upgrade(schain_name):
    print(f'Running revert_reason upgrade for {schain_name}')
    with open(EXPLORERS_META_DATA_PATH) as f:
        meta = json.loads(f.read())
        schain_meta = meta[schain_name]
    conn = psycopg2.connect(
        host="localhost",
        database="explorer",
        user="postgres",
        port=schain_meta['db_port'])

    provider = HTTPProvider(schain_meta['endpoint'])
    web3 = Web3(provider)
    cursor = conn.cursor()

    select_query = """SELECT hash,status,revert_reason 
                        FROM transactions 
                        WHERE status=0 AND revert_reason is null;"""
    cursor.execute(select_query)

    data = cursor.fetchall()
    data_to_update = []
    for i in data:
        hash = bytes(i[0]).hex()
        receipt = web3.eth.get_transaction_receipt(hash)
        if receipt.get('revertReason'):
            data_to_update.append((hash, receipt.revertReason))

    if data_to_update:
        print(f'Updating {len(data_to_update)} txs')
        update_query = """UPDATE transactions AS t
                          SET revert_reason = e.revert_reason
                          FROM (VALUES %s) AS e(hash, revert_reason)
                          WHERE decode(e.hash, 'hex') = t.hash;"""
        execute_values(cursor, update_query, data_to_update)
        conn.commit()
        print(f'sChain {schain_name} upgraded')


if __name__ == "__main__":
    if (sys.argv[1] == '--all'):
        with open(EXPLORERS_META_DATA_PATH) as f:
            meta = json.loads(f.read())
            for schain in meta.keys():
                try:
                    upgrade(schain)
                except Exception as e:
                    print(f'Failed to upgrade {schain}: {e}')
                    pass
    else:
        schains = sys.argv[1].split(',')
        for schain in schains:
            try:
                upgrade(schain)
            except Exception as e:
                print(f'Failed to upgrade {schain}: {e}')
                pass
