defmodule Explorer.Migrator.EmptyInternalTransactionsData do
  @moduledoc """
  Searches for all internal transactions with non-empty `trace_address` and empties it.
  Also searches for all internal transactions with zero `value` and empties it.
  Also updates `call_type` with `call_type_enum`.
  Also empties `error` column and fills `transaction_errors` with its values.
  Also fills `to_address_hash` column with the data from `created_contract_address_hash`.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query
  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.{InternalTransaction, TransactionError}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "empty_internal_transactions_data"

  @impl FillingMigration
  def migration_name, do: @migration_name

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
          not is_nil(it.trace_address) or it.value == ^0 or (is_nil(it.call_type_enum) and not is_nil(it.call_type)) or
            not is_nil(it.error) or (not is_nil(it.created_contract_address_hash) and is_nil(it.to_address_hash)),
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
            select_merge: %{error: it.error},
            where:
              it.block_number in ^block_numbers and
                (not is_nil(it.trace_address) or it.value == ^0 or
                   (is_nil(it.call_type_enum) and not is_nil(it.call_type)) or
                   not is_nil(it.error) or (not is_nil(it.created_contract_address_hash) and is_nil(it.to_address_hash))),
            order_by: [asc: it.transaction_hash, asc: it.index],
            lock: "FOR UPDATE"
          )

        extract_error_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            where: not is_nil(it.error),
            distinct: true,
            select: it.error
          )

        error_messages = Repo.all(extract_error_query, timeout: :infinity)

        TransactionError.find_or_create_multiple(error_messages)

        update_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            left_join: te in TransactionError,
            on: te.message == locked_it.error,
            update: [
              set: [
                error: nil,
                error_id:
                  fragment(
                    "CASE WHEN ? IS NOT NULL THEN COALESCE(?, ?) ELSE ? END",
                    it.error,
                    te.id,
                    it.error_id,
                    it.error_id
                  ),
                call_type_enum:
                  fragment(
                    "CASE WHEN ? IS NULL AND ? IS NOT NULL THEN (?::internal_transactions_call_type) ELSE ? END",
                    it.call_type_enum,
                    it.call_type,
                    it.call_type,
                    it.call_type_enum
                  ),
                call_type:
                  fragment(
                    "CASE WHEN ? IS NULL AND ? IS NOT NULL THEN NULL ELSE ? END",
                    it.call_type_enum,
                    it.call_type,
                    it.call_type
                  ),
                trace_address: nil,
                value: fragment("CASE WHEN ? = 0 THEN NULL ELSE ? END", it.value, it.value),
                to_address_hash:
                  fragment(
                    "CASE WHEN ? IS NOT NULL AND ? IS NULL THEN ? ELSE ? END",
                    it.created_contract_address_hash,
                    it.to_address_hash,
                    it.created_contract_address_hash,
                    it.to_address_hash
                  )
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
    BackgroundMigrations.set_empty_internal_transactions_data_finished(true)
  end
end
