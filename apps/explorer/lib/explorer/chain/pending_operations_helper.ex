defmodule Explorer.Chain.PendingOperationsHelper do
  @moduledoc false

  import Ecto.Query

  alias Explorer.Chain.{Hash, PendingBlockOperation, PendingTransactionOperation, Transaction}
  alias Explorer.{Helper, Repo}

  @transactions_batch_size 1000
  @blocks_batch_size 10

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
    pbo_params_query =
      from(
        pto in PendingTransactionOperation,
        join: t in assoc(pto, :transaction),
        select: %{block_hash: t.block_hash, block_number: t.block_number},
        limit: @transactions_batch_size
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
    from_blocks_to_transactions_function(@blocks_batch_size)
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
  Generates a query to find pending block operations that match any of the given block numbers.
  """
  @spec block_number_in_query([non_neg_integer()]) :: Ecto.Query.t()
  def block_number_in_query(block_numbers) do
    from(
      pending_ops in PendingBlockOperation,
      where: pending_ops.block_number in ^block_numbers
    )
  end

  @doc """
  Generates a query to find pending transaction operations that match any of the given transaction hashes.
  """
  @spec transaction_hash_in_query([Hash.Full.t()]) :: Ecto.Query.t()
  def transaction_hash_in_query(transaction_hashes) do
    from(
      pending_ops in PendingTransactionOperation,
      where: pending_ops.transaction_hash in ^transaction_hashes
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

  @doc """
  Checks if at least one block number from the provided list is pending.
  """
  @spec block_numbers_pending?([non_neg_integer()]) :: boolean()
  def block_numbers_pending?([]), do: false

  def block_numbers_pending?(block_numbers) do
    block_numbers
    |> block_number_in_query()
    |> Repo.exists?()
  end

  @doc """
  Checks if at least one transaction hash from the provided list is pending.
  """
  @spec transaction_hashes_pending?([Hash.Full.t()]) :: boolean()
  def transaction_hashes_pending?([]), do: false

  def transaction_hashes_pending?(transaction_hashes) do
    transaction_hashes
    |> transaction_hash_in_query()
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

  @spec transaction_block_range_in_query(non_neg_integer() | nil, non_neg_integer() | nil) :: Ecto.Query.t()
  defp transaction_block_range_in_query(min_block_number, max_block_number)
       when is_integer(min_block_number) and is_integer(max_block_number) do
    from(
      pending_ops in PendingTransactionOperation,
      join: t in assoc(pending_ops, :transaction),
      where: t.block_number >= ^min_block_number and t.block_number <= ^max_block_number
    )
  end

  defp transaction_block_range_in_query(min_block_number, max_block_number)
       when is_nil(min_block_number) and is_nil(max_block_number) do
    from(pending_ops in PendingTransactionOperation)
  end

  defp transaction_block_range_in_query(min_block_number, max_block_number) when is_nil(min_block_number) do
    from(
      pending_ops in PendingTransactionOperation,
      join: t in assoc(pending_ops, :transaction),
      where: t.block_number <= ^max_block_number
    )
  end

  defp transaction_block_range_in_query(min_block_number, max_block_number) when is_nil(max_block_number) do
    from(
      pending_ops in PendingTransactionOperation,
      join: t in assoc(pending_ops, :transaction),
      where: t.block_number >= ^min_block_number
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
  Checks if there are any pending transactions within the specified block range.
  """
  @spec transactions_pending_in_block_range?(non_neg_integer() | nil, non_neg_integer() | nil) :: boolean()
  def transactions_pending_in_block_range?(min_block_number, max_block_number) do
    min_block_number
    |> transaction_block_range_in_query(max_block_number)
    |> Repo.exists?()
  end

  @doc """
  Checks if there are any pending block or transaction operations within the specified block range.
  """
  @spec pending_operations_in_block_range?(non_neg_integer() | nil, non_neg_integer() | nil) :: boolean()
  def pending_operations_in_block_range?(min_block_number, max_block_number) do
    blocks_pending?(min_block_number, max_block_number) ||
      transactions_pending_in_block_range?(min_block_number, max_block_number)
  end

  @doc """
  Checks if there are any pending block or transaction operations in the system.
  """
  @spec any_pending_operations?() :: boolean()
  def any_pending_operations? do
    Repo.exists?(PendingBlockOperation) || Repo.exists?(PendingTransactionOperation)
  end

  @doc """
  Checks if there are pending operations for any of the provided block numbers or transaction hashes.
  """
  @spec pending_operations_for_blocks_or_transactions?([non_neg_integer()], [Hash.Full.t()]) :: boolean()
  def pending_operations_for_blocks_or_transactions?(block_numbers, transaction_hashes) do
    block_numbers_pending?(block_numbers) || transaction_hashes_pending?(transaction_hashes)
  end

  @doc """
  Checks if there are pending operations in a block-number range or among provided transaction hashes.
  """
  @spec pending_operations_for_block_range_or_transactions?(
          non_neg_integer() | nil,
          non_neg_integer() | nil,
          [Hash.Full.t()]
        ) :: boolean()
  def pending_operations_for_block_range_or_transactions?(min_block_number, max_block_number, transaction_hashes) do
    pending_operations_in_block_range?(min_block_number, max_block_number) ||
      transaction_hashes_pending?(transaction_hashes)
  end

  @doc """
  Checks if there are pending operations for a single transaction scope.
  """
  @spec pending_operations_for_transaction?(Hash.Full.t(), non_neg_integer() | nil) :: boolean()
  def pending_operations_for_transaction?(transaction_hash, block_number \\ nil) do
    transaction_hashes_pending?([transaction_hash]) ||
      if(is_nil(block_number), do: false, else: blocks_pending?(block_number, block_number))
  end
end
