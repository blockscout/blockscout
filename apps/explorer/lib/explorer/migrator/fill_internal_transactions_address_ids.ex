defmodule Explorer.Migrator.FillInternalTransactionsAddressIds do
  @moduledoc """
  Clears `*_address_hash` fields in internal transactions and fills their `*_address_id` copies.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query
  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Migrator.HeavyDbIndexOperation.RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError
  alias Explorer.Repo
  alias Explorer.Utility.AddressIdToAddressHash

  @migration_name "fill_internal_transactions_address_ids"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def dependent_from_migrations,
    do: [RemoveInternalTransactionsBlockHashTransactionHashBlockIndexError.migration_name()]

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"max_block_number" => -1} = state), do: {[], state}

  def last_unprocessed_identifiers(%{"max_block_number" => from_block_number} = state) do
    limit = batch_size() * concurrency()
    to_block_number = max(from_block_number - limit + 1, 0)

    {Enum.to_list(from_block_number..to_block_number), %{state | "max_block_number" => to_block_number - 1}}
  end

  def last_unprocessed_identifiers(state) do
    query =
      from(
        it in InternalTransaction,
        where:
          not is_nil(it.from_address_hash) or not is_nil(it.to_address_hash) or
            not is_nil(it.created_contract_address_hash),
        select: max(it.block_number)
      )

    max_block_number = Repo.one(query, timeout: :infinity)

    state
    |> Map.put("max_block_number", max_block_number || -1)
    |> last_unprocessed_identifiers()
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    Repo.transaction(
      fn ->
        lock_query =
          from(
            it in InternalTransaction,
            select: select_ctid(it),
            select_merge: %{
              from_address_hash: it.from_address_hash,
              to_address_hash: it.to_address_hash,
              created_contract_address_hash: it.created_contract_address_hash
            },
            where:
              it.block_number in ^block_numbers and
                (not is_nil(it.from_address_hash) or not is_nil(it.to_address_hash) or
                   not is_nil(it.created_contract_address_hash)),
            order_by: [asc: it.block_number, asc: it.transaction_index, asc: it.index],
            lock: "FOR UPDATE"
          )

        from_address_hashes_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            where: not is_nil(it.from_address_hash),
            distinct: true,
            select: it.from_address_hash
          )

        to_address_hashes_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            where: not is_nil(it.to_address_hash),
            distinct: true,
            select: it.to_address_hash
          )

        created_contract_address_hashes_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            where: not is_nil(it.created_contract_address_hash),
            distinct: true,
            select: it.created_contract_address_hash
          )

        from_address_hashes_query
        |> union_all(^to_address_hashes_query)
        |> union_all(^created_contract_address_hashes_query)
        |> Repo.all()
        |> Enum.uniq()
        |> AddressIdToAddressHash.find_or_create_multiple()

        update_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            left_join: from_map in AddressIdToAddressHash,
            on: from_map.address_hash == locked_it.from_address_hash,
            left_join: to_map in AddressIdToAddressHash,
            on: to_map.address_hash == locked_it.to_address_hash,
            left_join: created_map in AddressIdToAddressHash,
            on: created_map.address_hash == locked_it.created_contract_address_hash,
            update: [
              set: [
                from_address_id: from_map.address_id,
                to_address_id: coalesce(to_map.address_id, created_map.address_id),
                created_contract_address_id: created_map.address_id,
                from_address_hash: nil,
                to_address_hash: nil,
                created_contract_address_hash: nil
              ]
            ]
          )

        Repo.update_all(update_query, [], timeout: :infinity)
      end,
      timeout: :infinity
    )
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_fill_internal_transactions_address_ids_finished(true)
  end
end
