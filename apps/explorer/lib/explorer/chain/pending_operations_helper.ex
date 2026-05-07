defmodule Explorer.Chain.PendingOperationsHelper do
  @moduledoc false

  import Ecto.Query

  alias Explorer.Chain.{Block, Hash, PendingBlockOperation, PendingTransactionOperation, Transaction}
  alias Explorer.{Helper, Repo}

  defp transactions_batch_size,
    do:
      Application.get_env(:explorer, Explorer.Chain.PendingOperationsHelper)[:transactions_batch_size] ||
        1000

  defp blocks_batch_size,
    do: Application.get_env(:explorer, Explorer.Chain.PendingOperationsHelper)[:blocks_batch_size] || 10

  def pending_operations_type do
    if Application.get_env(:explorer, :json_rpc_named_arguments)[:variant] == EthereumJSONRPC.Geth and
         !Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)[:block_traceable?],
       do: "transactions",
       else: "blocks"
  end

  @doc """
  Deletes all entities from `PendingTransactionOperation` related to provided `transaction_hashes`.
  """
  @spec delete_related_transaction_operations([Hash.Full.t()]) :: {non_neg_integer(), nil}
  def delete_related_transaction_operations(transaction_hashes) do
    pending_operations_query =
      from(
        pto in PendingTransactionOperation,
        where: pto.transaction_hash in ^transaction_hashes,
        order_by: [asc: :transaction_hash],
        lock: "FOR UPDATE"
      )

    Repo.delete_all(
      from(
        pto in PendingTransactionOperation,
        join: s in subquery(pending_operations_query),
        on: pto.transaction_hash == s.transaction_hash
      )
    )
  end

  def actual_entity do
    case pending_operations_type() do
      "blocks" -> PendingBlockOperation
      "transactions" -> PendingTransactionOperation
    end
  end

  def maybe_transfuse_data do
    case {pending_operations_type(), data_exists?(PendingBlockOperation), data_exists?(PendingTransactionOperation)} do
      {"blocks", _blocks_data_exists?, true} -> do_transfuse(&from_transactions_to_blocks_function/0)
      {"transactions", true, _transactions_data_exists?} -> do_transfuse(&from_blocks_to_transactions_function/0)
      {_entity, _blocks_data_exists?, _transactions_data_exists?} -> :ok
    end
  end

  defp data_exists?(entity) do
    entity
    |> select([_], 1)
    |> limit(1)
    |> Repo.one()
    |> is_nil()
    |> Kernel.not()
  end

  defp do_transfuse(transfuse_function) do
    case Repo.transaction(transfuse_function) do
      {:ok, :finish} -> :ok
      {:ok, :continue} -> do_transfuse(transfuse_function)
    end
  end

  defp from_transactions_to_blocks_function do
    batch_size = transactions_batch_size()

    pbo_params_query =
      from(
        pto in PendingTransactionOperation,
        join: t in assoc(pto, :transaction),
        select: %{block_hash: t.block_hash, block_number: t.block_number, priority: pto.priority},
        limit: ^batch_size
      )

    case Repo.all(pbo_params_query) do
      [] ->
        :finish

      pbo_params ->
        filtered_pbo_params = Enum.reject(pbo_params, &is_nil(&1.block_hash))
        Repo.insert_all(PendingBlockOperation, Helper.add_timestamps(filtered_pbo_params), on_conflict: :nothing)

        block_numbers_to_delete = Enum.map(pbo_params, & &1.block_number)

        delete_query =
          from(
            pto in PendingTransactionOperation,
            join: t in assoc(pto, :transaction),
            where: is_nil(t.block_number) or t.block_number in ^block_numbers_to_delete
          )

        Repo.delete_all(delete_query)

        :continue
    end
  end

  defp from_blocks_to_transactions_function do
    from_blocks_to_transactions_function(blocks_batch_size())
  end

  defp from_blocks_to_transactions_function(blocks_batch_size) do
    pbo_block_numbers_query =
      PendingBlockOperation
      |> limit(^blocks_batch_size)
      |> select([pbo], pbo.block_number)

    case Repo.all(pbo_block_numbers_query) do
      [] ->
        :finish

      pbo_block_numbers ->
        pto_params =
          Transaction
          |> where([t], t.block_number in ^pbo_block_numbers)
          |> select([t], %{hash: t.hash, type: t.type})
          |> Repo.all()
          |> Transaction.filter_non_traceable_transactions()
          |> Enum.map(&%{transaction_hash: &1.hash})
          |> Helper.add_timestamps()

        case insert_pending_transaction_operations(pto_params) do
          :ok ->
            delete_pending_block_operations(pbo_block_numbers)

            :continue

          {:error, :too_many_parameters} when blocks_batch_size > 1 ->
            from_blocks_to_transactions_function(max(div(blocks_batch_size, 2), 1))

          {:error, :too_many_parameters} ->
            Repo.safe_insert_all(PendingTransactionOperation, pto_params, on_conflict: :nothing)
            delete_pending_block_operations(pbo_block_numbers)

            :continue
        end
    end
  end

  defp insert_pending_transaction_operations([]), do: :ok

  defp insert_pending_transaction_operations(pto_params) do
    Repo.insert_all(PendingTransactionOperation, pto_params, on_conflict: :nothing)
    :ok
  rescue
    error in Postgrex.QueryError ->
      if too_many_parameters_error?(error) do
        {:error, :too_many_parameters}
      else
        reraise error, __STACKTRACE__
      end
  end

  defp delete_pending_block_operations(pbo_block_numbers) do
    PendingBlockOperation
    |> where([pbo], pbo.block_number in ^pbo_block_numbers)
    |> Repo.delete_all()
  end

  defp too_many_parameters_error?(%Postgrex.QueryError{message: message}) when is_binary(message) do
    Regex.match?(~r/postgresql protocol can not handle \d+ parameters, the maximum is \d+/i, message)
  end

  defp too_many_parameters_error?(_), do: false

  @doc """
  Generates a query to find pending block operations that match any of the given block hashes.

  ## Parameters

    - `block_hashes`: A list of block hashes to filter the pending block operations.

  ## Returns

    - An Ecto query that can be executed to retrieve the matching pending block operations.
  """
  @spec block_hash_in_query([Hash.Full.t()]) :: Ecto.Query.t()
  def block_hash_in_query(block_hashes) do
    from(
      pending_ops in PendingBlockOperation,
      where: pending_ops.block_hash in ^block_hashes
    )
  end

  @doc """
  Checks if a block with the given hash is pending.
  A block is considered pending if there exists a corresponding entry in the `PendingBlockOperation` table.
  """
  @spec block_pending?(Hash.Full.t()) :: boolean()
  def block_pending?(block_hash) do
    [block_hash]
    |> block_hash_in_query()
    |> Repo.exists?()
  end

  # Generates a query to find pending block operations within a specified range of block numbers.
  @spec block_range_in_query(non_neg_integer(), non_neg_integer()) :: Ecto.Query.t()
  defp block_range_in_query(min_block_number, max_block_number)
       when is_integer(min_block_number) and is_integer(max_block_number) do
    from(
      pending_ops in PendingBlockOperation,
      where: pending_ops.block_number >= ^min_block_number and pending_ops.block_number <= ^max_block_number
    )
  end

  defp block_range_in_query(min_block_number, max_block_number)
       when is_nil(min_block_number) and is_nil(max_block_number) do
    from(pending_ops in PendingBlockOperation)
  end

  defp block_range_in_query(min_block_number, max_block_number) when is_nil(min_block_number) do
    from(
      pending_ops in PendingBlockOperation,
      where: pending_ops.block_number <= ^max_block_number
    )
  end

  defp block_range_in_query(min_block_number, max_block_number) when is_nil(max_block_number) do
    from(
      pending_ops in PendingBlockOperation,
      where: pending_ops.block_number >= ^min_block_number
    )
  end

  @doc """
  Checks if there are any pending blocks within the specified range of block numbers.
  A block is considered pending if there exists a corresponding entry in the `PendingBlockOperation`
  table.
  """
  @spec blocks_pending?(non_neg_integer() | nil, non_neg_integer() | nil) :: boolean()
  def blocks_pending?(min_block_number, max_block_number) do
    min_block_number
    |> block_range_in_query(max_block_number)
    |> Repo.exists?()
  end

  @doc """
    Inserts pending operations for the given block numbers.
  """
  @spec insert_pending_operations([integer()], integer() | nil) :: {[integer()], [Explorer.Chain.Transaction.t()]}
  def insert_pending_operations(block_numbers, priority \\ nil) do
    case pending_operations_type() do
      "transactions" ->
        default_on_conflict = default_pto_on_conflict()
        transactions = Transaction.get_transactions_of_block_numbers(block_numbers)

        pto_params =
          transactions
          |> Transaction.filter_non_traceable_transactions()
          |> Enum.map(&%{transaction_hash: &1.hash, priority: priority})
          |> Helper.add_timestamps()

        Repo.insert_all(PendingTransactionOperation, pto_params,
          on_conflict: default_on_conflict,
          conflict_target: [:transaction_hash]
        )

        {[], transactions}

      "blocks" ->
        default_on_conflict = default_pbo_on_conflict()

        pbo_params =
          Block
          |> where([b], b.number in ^block_numbers)
          |> where([b], b.consensus == true)
          |> select([b], %{block_hash: b.hash, block_number: b.number})
          |> Repo.all()
          |> add_priority(priority)
          |> Helper.add_timestamps()

        {_total, inserted} =
          Repo.insert_all(PendingBlockOperation, pbo_params,
            on_conflict: default_on_conflict,
            conflict_target: [:block_hash],
            returning: [:block_number]
          )

        {Enum.map(inserted, & &1.block_number), []}
    end
  end

  defp default_pbo_on_conflict do
    from(
      pending_block_operation in PendingBlockOperation,
      update: [
        set: [
          priority: fragment("EXCLUDED.priority"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", pending_block_operation.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", pending_block_operation.updated_at)
        ]
      ],
      where: is_nil(pending_block_operation.priority) and fragment("EXCLUDED.priority IS NOT NULL")
    )
  end

  defp default_pto_on_conflict do
    from(
      pending_transaction_operation in PendingTransactionOperation,
      update: [
        set: [
          priority: fragment("EXCLUDED.priority"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", pending_transaction_operation.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", pending_transaction_operation.updated_at)
        ]
      ],
      where: is_nil(pending_transaction_operation.priority) and fragment("EXCLUDED.priority IS NOT NULL")
    )
  end

  defp add_priority(params, priority) do
    Enum.map(params, &Map.merge(&1, %{priority: priority}))
  end
end
