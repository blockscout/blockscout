defmodule Explorer.Chain.PendingOperationsHelper do
  @moduledoc false

  import Ecto.Query

  alias Explorer.Chain.{Hash, PendingBlockOperation, PendingTransactionOperation, Transaction}
  alias Explorer.{Helper, Repo}

  @transactions_batch_size 1000
  @blocks_batch_size 10

  def pending_operations_type do
    # TODO: bring back this condition after the migration of internal transactions PK to [:block_hash, :transaction_index, :index]
    # if Application.get_env(:explorer, :json_rpc_named_arguments)[:variant] == EthereumJSONRPC.Geth and
    #      not Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)[:block_traceable?],
    #    do: "transactions",
    #    else: "blocks"

    if Application.get_env(:explorer, :non_existing_variable, false) do
      "transactions"
    else
      "blocks"
    end
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
        Repo.insert_all(PendingBlockOperation, Helper.add_timestamps(pbo_params), on_conflict: :nothing)

        block_numbers_to_delete = Enum.map(pbo_params, & &1.block_number)

        delete_query =
          from(
            pto in PendingTransactionOperation,
            join: t in assoc(pto, :transaction),
            where: t.block_number in ^block_numbers_to_delete
          )

        Repo.delete_all(delete_query)

        :continue
    end
  end

  defp from_blocks_to_transactions_function do
    pbo_block_numbers_query =
      PendingBlockOperation
      |> limit(@blocks_batch_size)
      |> select([pbo], pbo.block_number)

    case Repo.all(pbo_block_numbers_query) do
      [] ->
        :finish

      pbo_block_numbers ->
        pto_params =
          Transaction
          |> where([t], t.block_number in ^pbo_block_numbers)
          |> select([t], %{transaction_hash: t.hash})
          |> Repo.all()
          |> Helper.add_timestamps()

        Repo.insert_all(PendingTransactionOperation, pto_params, on_conflict: :nothing)

        PendingBlockOperation
        |> where([pbo], pbo.block_number in ^pbo_block_numbers)
        |> Repo.delete_all()

        :continue
    end
  end

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
end
