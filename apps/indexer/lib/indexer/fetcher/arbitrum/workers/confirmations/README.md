# Confirmation Processing Modules

This directory contains the modules that discover the confirmations of rollup blocks in the Arbitrum indexer.

## Module Overview

- **`events.ex`**  
  Fetches the `SendRootUpdated` events of the Arbitrum `Outbox` contract for a range of parent chain blocks. It also parses the hash of the confirmed rollup block from an event.

- **`discovery.ex`**  
  Reads one window of the parent chain. It prepares the rows of the table of confirmations and the lifecycle transactions. It also prepares the L2-to-L1 messages that become confirmed. It does not write to the database.

- **`tasks.ex`**  
  Runs the main process and the backfill process. Each process reads one window in each run, imports the result of the window together with its cursor, and moves its cursor.

## The data structure

The table `arbitrum_rollup_block_confirmations` holds one row for each `SendRootUpdated` event. A row has the rollup block `top` that the event confirms, and the lifecycle transaction of the event. The column `top` is unique.

The order of `top` gives the rollup blocks of each row. A row owns the rollup blocks above the `top` of the row below it, up to its own `top`. The lowest row owns the blocks from 0. If a row with `top` not below a rollup block exists, the rollup block is confirmed. The row with the lowest such `top` holds the confirmation transaction of the block.

The discovery only adds rows. It never changes or deletes a row. Thus the rows always cover the rollup blocks from 0 to the highest `top`, without gaps and without overlaps. The position of an event in the parent chain does not change the result of the events that the discovery reads. This also holds for an AnyTrust chain, where an older parent chain block can hold the confirmation of a higher rollup block. The second stop rule of the backfill process limits the set of the events that the discovery reads, see "The processes".

## The processes

Both processes read the parent chain in windows. A window is a range of parent chain blocks. Its size is `INDEXER_ARBITRUM_L1_RPC_HISTORICAL_BLOCKS_RANGE`. Each process keeps a cursor in the table `last_fetched_counters`: the number of the last parent chain block that the process read. The process writes the rows of a window and its cursor in one database transaction.

At the first start, the start point is the parent chain block of the commitment of the latest batch. The main process reads up from the start point. The backfill process reads down from the block below it. If `INDEXER_ARBITRUM_CONFIRMATIONS_TRACKING_FINALIZED` is `true`, the start point is not above the safe block of the parent chain, because the backfill process reads a block only once. The start point is not below `INDEXER_ARBITRUM_L1_ROLLUP_INIT_BLOCK`. If no batch exists, the discovery waits and writes a log message. The backfill process then runs again after the recheck interval of the main process, not after the short catchup interval.

The main process does not start while the table of the confirmations is empty and the backfill cursor is above `INDEXER_ARBITRUM_L1_ROLLUP_INIT_BLOCK`. The first event that the backfill process finds confirms almost all indexed rollup blocks.

The backfill process stops in two cases:

- Its cursor reaches `INDEXER_ARBITRUM_L1_ROLLUP_INIT_BLOCK`.
- It finds an event with a `top` below the lowest rollup block that the instance indexes. The process adds the event and sets its cursor to `INDEXER_ARBITRUM_L1_ROLLUP_INIT_BLOCK`.

The second stop rule is best effort. In the inverted order, an older parent chain block below the stop window can hold an event with a `top` not below the lowest indexed rollup block. The backfill process does not read this event. Example: the lowest indexed rollup block is 1000. The stop window holds an event with `top` 900 in the parent chain block 5000, and the parent chain block 4500 holds an event with `top` 1200. The backfill process stops at the first event, and it never adds the second one. The main process adds a later event with a higher `top`, and the API shows the transaction of that later event as the confirmation of the rollup blocks 1000 to 1200. The status of a block or a message does not change, because the later event confirms the same rollup blocks.

If `INDEXER_ARBITRUM_CONFIRMATIONS_TRACKING_FINALIZED` is `false`, each window of the main process starts at the lower of the block after the cursor and the safe block. Thus the process reads the blocks above the safe block again, and a re-org of the parent chain does not lose an event. The upsert of the lifecycle transaction on its hash updates the block number and the timestamp of a moved transaction.

If an RPC request fails, the process does not move its cursor and reads the same window again. A repeated window does not damage the data: the import of a row with a known `top` does nothing.

## The lower bound of other discoveries

The discovery of historical executions of L2-to-L1 messages does not use the table of confirmations. An execution comes after the confirmation of the rollup block of the message, and a confirmation comes after the commitment of the batch that holds the rollup block. Thus the lower bound of that discovery is the parent chain block of the commitment of the batch that holds the first indexed rollup block, and not below `INDEXER_ARBITRUM_L1_ROLLUP_INIT_BLOCK`. The bound does not depend on the confirmations that the backfill process found. An inverted-order confirmation below the window where the backfill process stopped does not change it. See `Indexer.Fetcher.Arbitrum.Workers.NewL1Executions`.

## Update & Extension Guidelines

- Keep the operation that adds a confirmation free of the position of the event in the parent chain. The table stores only `top`.
- Keep both processes as tasks of `Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses`, which runs one task at a time. The identifiers of the lifecycle transactions are not safe against parallel writers.
- Write the cursor of a process only together with the rows of its window.
- The API reads the confirmation of a rollup block through `Explorer.Chain.Arbitrum.Reader.Common.confirmation_transaction_for_rollup_block/2`. Keep the table small: one row for each event.
