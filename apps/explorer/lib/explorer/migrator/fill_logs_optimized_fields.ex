# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.FillLogsOptimizedFields do
  @moduledoc """
  Fills `transaction_index`, `address_id` fields in `logs` table.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query
  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.{Log, Transaction}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsFirstTopicIdIndex
  alias Explorer.Repo
  alias Explorer.Utility.{AddressIdToAddressHash, LogFirstTopic}

  @migration_name "fill_logs_optimized_fields"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def dependent_from_migrations,
    do: [CreateLogsFirstTopicIdIndex.migration_name()]

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"max_block_number" => -1} = state), do: {[], state}

  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    block_numbers =
      state
      |> unprocessed_data_query()
      |> select([l], l.block_number)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    max_block_number =
      case List.last(block_numbers) do
        nil -> -1
        block_number -> block_number - 1
      end

    {block_numbers, Map.put(state, "max_block_number", max_block_number)}
  end

  @impl FillingMigration
  def unprocessed_data_query(state) do
    Log
    |> where(^not_migrated_condition())
    |> then(fn query ->
      case Map.get(state, "max_block_number") do
        nil -> query
        max_block_number -> where(query, [l], l.block_number <= ^max_block_number)
      end
    end)
    |> order_by([l], desc: l.block_number)
  end

  # Groups the blocks into batches of about `batch_size` logs. A block is never split between the batches,
  # so all its logs are migrated by the same task. Since every batch except the last one has at least
  # `batch_size` logs, there are no more batches than `concurrency`.
  @impl FillingMigration
  def split_into_batches(block_numbers) do
    batch_size = batch_size()

    block_numbers
    |> Enum.chunk_by(& &1)
    |> Enum.chunk_while(
      {[], 0},
      fn [block_number | _] = block_logs, {batch, logs_count} ->
        batch = [block_number | batch]
        logs_count = logs_count + length(block_logs)

        if logs_count >= batch_size do
          {:cont, Enum.reverse(batch), {[], 0}}
        else
          {:cont, {batch, logs_count}}
        end
      end,
      fn
        {[], _logs_count} -> {:cont, {[], 0}}
        {batch, _logs_count} -> {:cont, Enum.reverse(batch), {[], 0}}
      end
    )
  end

  @impl FillingMigration
  def update_batch(block_numbers) do
    {:ok, {count, _}} =
      Repo.transaction(
        fn ->
          lock_query =
            from(
              l in Log,
              select: select_ctid(l),
              select_merge: %{
                address_hash: l.address_hash,
                transaction_hash: l.transaction_hash,
                first_topic: l.first_topic
              },
              where: l.block_number in ^block_numbers,
              where: ^not_migrated_condition(),
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

          first_topics_query =
            from(l in Log,
              inner_join: locked_l in subquery(lock_query),
              on: join_on_ctid(l, locked_l),
              where: not is_nil(l.first_topic),
              distinct: true,
              select: l.first_topic
            )

          address_hashes_query
          |> Repo.all()
          |> Enum.uniq()
          |> AddressIdToAddressHash.find_or_create_multiple()

          first_topics_query
          |> Repo.all()
          |> LogFirstTopic.find_or_create_multiple()

          update_query =
            from(l in Log,
              inner_join: locked_l in subquery(lock_query),
              on: join_on_ctid(l, locked_l),
              left_join: it_to_hash_map in AddressIdToAddressHash,
              on: it_to_hash_map.address_hash == locked_l.address_hash,
              left_join: t in Transaction,
              on: locked_l.transaction_hash == t.hash,
              left_join: lft in LogFirstTopic,
              on: lft.value == locked_l.first_topic,
              update: [
                set: [
                  address_id: coalesce(it_to_hash_map.address_id, l.address_id),
                  address_hash: nil,
                  first_topic_id: coalesce(lft.id, l.first_topic_id),
                  first_topic: nil,
                  # Logs which are not linked to a transaction (Celo epoch logs) keep `NULL`:
                  # `transaction_index` is nullable and excluded from the primary key for such
                  # chains. For the rest the already filled value is kept, and the number of
                  # transactions in the block is used as a last resort, since `transaction_index`
                  # is `NOT NULL` there: it can't collide with the index of any real transaction
                  # of the block.
                  transaction_index:
                    fragment(
                      "COALESCE(?, ?, CASE WHEN ? IS NOT NULL THEN (SELECT count(*) FROM transactions WHERE block_number = ?) END)",
                      t.index,
                      l.transaction_index,
                      l.transaction_hash,
                      l.block_number
                    ),
                  second_topic: fragment("bytea_ltrim_zeroes(?)", l.second_topic),
                  third_topic: fragment("bytea_ltrim_zeroes(?)", l.third_topic),
                  fourth_topic: fragment("bytea_ltrim_zeroes(?)", l.fourth_topic)
                ]
              ]
            )

          Repo.update_all(update_query, [], timeout: :infinity)
        end,
        timeout: :infinity
      )

    count
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_fill_logs_optimized_fields_finished(true)
  end

  defp not_migrated_condition do
    dynamic(
      [l],
      not is_nil(l.address_hash) or not is_nil(l.first_topic) or
        (is_nil(l.transaction_index) and not is_nil(l.transaction_hash))
    )
  end
end
