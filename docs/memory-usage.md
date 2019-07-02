<!--memory-usage.md -->

## Memory Usage

The work queues for building the index of all blocks, balances (coin and token), and internal transactions can grow quite large.  By default, the soft-limit is 1 GiB, which can be changed in `apps/indexer/config/config.exs`:

```
config :indexer, memory_limit: 1 <<< 30
```

Memory usage is checked once per minute.  If the soft-limit is reached, the shrinkable work queues will shed half their load.  The shed load will be restored from the database, the same as when a restart of the server occurs, so rebuilding the work queue will be slower, but use less memory.

If all queues are at their minimum size, then no more memory can be reclaimed and an error will be logged.