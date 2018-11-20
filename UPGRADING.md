# Upgrading Guide

### Migration scripts

There is in the project a `scripts` folder that contains `SQL` files responsible to migrate data from the database.

This script should be used if you already have an indexed database with a large amount of data.

#### `address_current_token_balances_in_batches.sql`

Is responsible to populate a new table using the `token_balances` table information.

#### `internal_transaction_update_in_batches.sql`

Is responsible to migrate data from the `transactions` table to the `internal_transactions` one in order to improve the application listing performance;

#### `transaction_update_in_baches.sql`

Parity call traces contain the input, but it was not put in the internal_transactions_params.
Enforce input and call_type being non-NULL for calls in new constraints on internal_transactions.
