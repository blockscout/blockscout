import json

import psycopg2
from psycopg2.extras import execute_values
from web3 import HTTPProvider, Web3

from admin import EXPLORERS_META_DATA_PATH


def upgrade(schain_name):
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

    update_query = """UPDATE transactions AS t
                      SET revert_reason = e.revert_reason
                      FROM (VALUES %s) AS e(hash, revert_reason)
                      WHERE decode(e.hash, 'hex') = t.hash;"""
    execute_values(cursor, update_query, data_to_update)
    conn.commit()
