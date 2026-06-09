# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.FillLogsTransactionIndexAddressId do
  @moduledoc """
  Fills `transaction_index`, `address_id` fields in `logs` table.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query
  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

  alias Explorer.Chain.Cache.{BackgroundMigrations, BlockNumber}
  alias Explorer.Chain.{Log, Transaction}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockNumberTransactionIndexIndexUniqueIndex
  alias Explorer.Repo
  alias Explorer.Utility.AddressIdToAddressHash

  @migration_name "fill_logs_transaction_index_address_id"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def dependent_from_migrations,
    do: [CreateLogsBlockNumberTransactionIndexIndexUniqueIndex.migration_name()]

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"max_block_number" => -1} = state), do: {[], state}

  def last_unprocessed_identifiers(state) do
    block_number = state["max_block_number"] || BlockNumber.get_max()

    limit = batch_size() * concurrency()

    from_block_number = max(block_number - limit, 0)

    {Enum.to_list(from_block_number..block_number), Map.put(state, "max_block_number", from_block_number - 1)}
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    Repo.transaction(
      fn ->
        lock_query =
          from(
            l in Log,
            select: select_ctid(l),
            select_merge: %{address_hash: l.address_hash, transaction_hash: l.transaction_hash},
            where: l.block_number in ^block_numbers,
            order_by: [asc: l.block_number, asc: l.transaction_index, asc: l.index],
            lock: "FOR UPDATE"
          )

        address_hashes_query =
          from(l in Log,
            inner_join: locked_l in subquery(lock_query),
            on: join_on_ctid(l, locked_l),
            where: not is_nil(l.address_hash),
            distinct: true,
            select: l.address_hash
          )

        address_hashes_query
        |> Repo.all()
        |> Enum.uniq()
        |> AddressIdToAddressHash.find_or_create_multiple()

        update_query =
          from(l in Log,
            inner_join: locked_l in subquery(lock_query),
            on: join_on_ctid(l, locked_l),
            left_join: it_to_hash_map in AddressIdToAddressHash,
            on: it_to_hash_map.address_hash == locked_l.address_hash,
            left_join: t in Transaction,
            on: locked_l.transaction_hash == t.hash,
            update: [
              set: [
                address_id: it_to_hash_map.address_id,
                address_hash: nil,
                transaction_index: t.index
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
    BackgroundMigrations.set_fill_logs_transaction_index_address_id_finished(true)
  end
end
