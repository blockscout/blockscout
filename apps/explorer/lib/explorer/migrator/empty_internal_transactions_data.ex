defmodule Explorer.Migrator.EmptyInternalTransactionsData do
  @moduledoc """
  Searches for all internal transactions with non-empty `trace_address` and empties it.
  Also searches for all internal transactions with zero `value` and empties it.
  Also updates `call_type` with `call_type_enum`.
  Also empties `error` column and fills `transaction_errors` with its values.
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
            not is_nil(it.error),
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
            where: it.block_number in ^block_numbers,
            order_by: [asc: it.transaction_hash, asc: it.index],
            lock: "FOR UPDATE"
          )

        trace_address_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            where: not is_nil(it.trace_address),
            update: [set: [trace_address: nil]]
          )

        Repo.update_all(trace_address_query, [], timeout: :infinity)

        value_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            where: it.value == ^0,
            update: [set: [value: nil]]
          )

        Repo.update_all(value_query, [], timeout: :infinity)

        call_type_query =
          from(it in InternalTransaction,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            where: is_nil(it.call_type_enum) and not is_nil(it.call_type),
            update: [
              set: [call_type_enum: fragment("?::internal_transactions_call_type", it.call_type), call_type: nil]
            ]
          )

        Repo.update_all(call_type_query, [], timeout: :infinity)

        extract_error_query =
          from(it in InternalTransaction,
            where: it.block_number in ^block_numbers,
            where: not is_nil(it.error),
            select: it.error
          )

        error_messages = Repo.all(extract_error_query, timeout: :infinity)

        TransactionError.find_or_create_multiple(error_messages)

        error_update_query =
          from(it in InternalTransaction,
            inner_join: te in TransactionError,
            on: te.message == it.error,
            inner_join: locked_it in subquery(lock_query),
            on: join_on_ctid(it, locked_it),
            where: not is_nil(it.error),
            update: [set: [error: nil, error_id: te.id]]
          )

        Repo.update_all(error_update_query, [], timeout: :infinity)
      end,
      timeout: :infinity
    )
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_empty_internal_transactions_data_finished(true)
  end
end
