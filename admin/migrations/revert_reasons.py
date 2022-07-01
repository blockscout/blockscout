import json
import logging

import psycopg2
from psycopg2.extras import execute_values
from web3 import HTTPProvider, Web3
from admin import EXPLORERS_META_DATA_PATH
from admin.endpoints import write_json, read_json

logger = logging.getLogger(__name__)


def upgrade_revert_reasons(schain_name):
    logger.info(f'Running revert_reason upgrade for {schain_name}')
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
    limit_number = 1000
    select_query = f"""SELECT hash,status,revert_reason,block_number 
                        FROM transactions 
                        WHERE status=0 AND revert_reason is null 
                        ORDER BY block_number DESC LIMIT {limit_number};"""
    cursor.execute(select_query)

    data = cursor.fetchall()
    logger.info(f'Found {len(data)} txs to be checked')
    data_to_update = []
    for i in data:
        hash = bytes(i[0]).hex()
        try:
            receipt = web3.eth.get_transaction_receipt(hash)
            if receipt.get('revertReason'):
                data_to_update.append((hash, receipt.revertReason))
        except Exception:
            continue

    if data_to_update:
        logger.info(f'Updating {len(data_to_update)} txs')
        update_query = """UPDATE transactions AS t
                          SET revert_reason = e.revert_reason
                          FROM (VALUES %s) AS e(hash, revert_reason)
                          WHERE decode(e.hash, 'hex') = t.hash;"""
        execute_values(cursor, update_query, data_to_update)
        conn.commit()


def set_schain_upgraded(schain_name):
    with open(EXPLORERS_META_DATA_PATH) as f:
        meta = json.loads(f.read())
        schain_meta = meta[schain_name]
        schain_meta['updated'] = True
        meta.update({
            schain_name: schain_meta
        })
        write_json(EXPLORERS_META_DATA_PATH, meta)


def is_schain_upgraded(schain_name):
    explorers = read_json(EXPLORERS_META_DATA_PATH)
    schain_meta = explorers.get(schain_name)
    if not schain_meta or schain_meta.get('updated'):
        return True


def upgrade(schain_name):
    try:
        upgrade_revert_reasons(schain_name)
        set_schain_upgraded(schain_name)
        logger.info(f'sChain {schain_name} upgraded')
    except Exception as e:
        print(f'Failed to upgrade {schain_name}: {e}')
