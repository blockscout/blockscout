<!--sharelocks.md -->

## ShareLocks

ShareLock is the row-level locking mechanism used internally by PostgreSQL.

### Deadlocks and prevention

When several DB transactions are acting on multiple rows of the same table, it's
possible to incur in a deadlock and so into an error.
This can be prevented by enforcing the same consistent order of lock aquisition
on *all* the transactions performing `INSERT`, `UPDATE` or `DELETE` on a given table.

On top of this, if multiple DB transactions act on multiple tables a deadlock
will occur, even if they follow the order on each table described above, if they
acquire locks on said tables in a different order.
This can also be prevented by using a consisten order of lock acquisition *between*
different tables.

### Imposing the lock acquisition order on a table with Ecto

When `INSERT`ing a list of rows Postgres will respect the order in which they
appear in the query, so the reordering can happen beforehand.

For example, this will work:
```elixir
entries = [...]

ordered_entries = Enum.sort_by(entries, & &1.id)

Repo.insert_all(__MODULE__, ordered_entries)
```

Performing `UPDATE`s is trickier because there is no `ORDER BY` clause.
The solution to this is to `JOIN` on a subquery that `SELECT`s with the option `FOR UPDATE`.

Using Ecto this can be done, for example, like this:
```elixir
query =
  from(
    entry in Entry,
    where: not is_nil(entry.value),
    order_by: entry.id,
    lock: "FOR UPDATE"
  )

Repo.update_all(
  from(e in Entry, join: s in subquery(query), on: e.id == s.id),
  [set: [value: nil]],
  timeout: timeout)
```

`DELETE` has the same quircks as `UPDATE` and it is too solved in the same way.

For example:
```elixir
query =
  from(
    entry in Entry,
    where: is_nil(entry.value),
    order_by: entry.id,
    lock: "FOR UPDATE"
  )

Repo.delete_all(from(e in Entry, join: s in subquery(query), on: e.id == s.id))
```

### Imposing the lock acquisition order between tables with Ecto

When using an `Ecto.Multi` to perform `INSERT`, `UPDATE` or `DELETE` on multiple
tables the order to keep is between different operation.
For example, supposing `EntryA` was established to be modified before `EntryB`,
this is not correct:
```elixir
Multi.new()
|> Multi.run(:update_b, fn repo, _ ->
  # operations with ordered locks on `EntryB`
end)
|> Multi.run(:update_a, fn repo, _ ->
  # operations with ordered locks on `EntryA`
end)
|> Repo.transaction()
```

When possible, the simple solution is to move `:update_a` to be before `:update_b`.
When not possible, for instance if `:update_a` depends on the result of `:update_b`,
this can be solved by acquiring the locks in a separate operation.

For example:
```elixir
Multi.new()
|> Multi.run(:acquire_a, fn repo, _ ->
  # acquire locks in order on `EntryA`
end)
|> Multi.run(:update_b, fn repo, _ ->
  # operations with ordered locks on `EntryB`
end)
|> Multi.run(:update_a, fn repo, %{acquire_a: values} ->
  # operations (no need to enforce order again) on `EntryA`
end)
|> Repo.transaction()
```

Note also that for the same reasons multiple operations on the same table in the
same transaction are not safe to perform if they each acquire locks in order,
because locks are not released until the transaction is committed.

### Order used for Explorer's tables

This is a complete list of the ordering currently in use on each table.
It also specifies the order between tables in the same transaction: locks for a
table on top need to be acquired before those from a table on the bottom.

Note that this should always be enforced because as long as there is one DB
transaction performing in a different order there is the possibility of a deadlock.

| schema module | table name | ordered by |
|---------------|------------|------------|
| Explorer.Chain.Address | addresses | asc: :hash |
| Explorer.Chain.Address.Name | address_names | [asc: :address_hash, asc: :name] |
| Explorer.Chain.Address.CoinBalance | address_coin_balances | [asc: :address_hash, asc: :block_number] |
| Explorer.Chain.Block | blocks | asc: :hash |
| Explorer.Chain.Block.SecondDegreeRelation | block_second_degree_relations | [asc: :nephew_hash, asc: :uncle_hash] |
| Explorer.Chain.Block.Reward | block_rewards | [asc: :address_hash, asc: :address_type, asc: :block_hash] |
| Explorer.Chain.Block.EmissionReward | emission_rewards | asc: :block_range |
| Explorer.Chain.Transaction | transactions | asc: :hash |
| Explorer.Chain.Transaction.Fork | transaction_forks | [asc: :uncle_hash, asc: :index] |
| Explorer.Chain.Log | logs | [asc: :transaction_hash, asc: :index] |
| Explorer.Chain.InternalTransaction | internal_transactions | [asc: :transaction_hash, asc: :index] |
| Explorer.Chain.Token | tokens | asc: :contract_address_hash |
| Explorer.Chain.TokenTransfer | token_transfers | [asc: :transaction_hash, asc: :log_index]|
| Explorer.Chain.Address.TokenBalance | address_token_balances | [asc: :address_hash, asc: :token_contract_address_hash, asc: :block_number] |
| Explorer.Chain.Address.CurrentTokenBalance | address_current_token_balances | [asc: :address_hash, asc: :token_contract_address_hash] |
| Explorer.Chain.StakingPool | staking_pools | :staking_address_hash |
| Explorer.Chain.StakingPoolsDelegator | staking_pools_delegators | [asc: :delegator_address_hash, asc: :pool_address_hash] |
| Explorer.Chain.ContractMethod | contract_methods | [asc: :identified, asc: :abi]
| Explorer.Market.MarketHistory | market_history | asc: :date |
