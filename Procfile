web: bin/start-pgbouncer-stunnel mix phx.server
worker: bin/start-pgbouncer-stunnel mix exq.start
scheduler: bin/start-pgbouncer-stunnel mix exq.start scheduler
blocks: bin/start-pgbouncer-stunnel mix scrape.blocks 1000000
receipts: bin/start-pgbouncer-stunnel mix scrape.receipts 10000
internal_transactions: bin/start-pgbouncer-stunnel mix scrape.internal_transactions 10000
balances: bin/start-pgbouncer-stunnel mix scrape.balances 1000000
