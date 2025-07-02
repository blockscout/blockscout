defmodule Indexer.PendingTransactionsSanitizer do
  @moduledoc """
  Periodically checks pending transactions status in order to detect that transaction already included to the block
  And we need to re-fetch that block.
  """

  use GenServer

  require Logger

  import EthereumJSONRPC, only: [json_rpc: 2, request: 1, id_to_params: 1]
  import EthereumJSONRPC.Receipt, only: [to_elixir: 1]

  alias Ecto.Changeset
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Transaction}

  defstruct interval: nil,
            json_rpc_named_arguments: []

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    default = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments}
    }

    Supervisor.child_spec(default, [])
  end

  def start_link(init_opts, gen_server_opts \\ []) do
    GenServer.start_link(__MODULE__, init_opts, gen_server_opts)
  end

  def init(opts) when is_list(opts) do
    state = %__MODULE__{
      json_rpc_named_arguments: Keyword.fetch!(opts, :json_rpc_named_arguments),
      interval: Application.get_env(:indexer, __MODULE__)[:interval]
    }

    Process.send_after(self(), :sanitize_pending_transactions, state.interval)

    {:ok, state}
  end

  def handle_info(
        :sanitize_pending_transactions,
        %{interval: interval, json_rpc_named_arguments: json_rpc_named_arguments} = state
      ) do
    Logger.debug("Start sanitizing of pending transactions",
      fetcher: :pending_transactions_to_refetch
    )

    sanitize_pending_transactions(json_rpc_named_arguments)

    Process.send_after(self(), :sanitize_pending_transactions, interval)

    {:noreply, state}
  end

  defp sanitize_pending_transactions(json_rpc_named_arguments) do
    receipts_batch_size = Application.get_env(:indexer, :receipts_batch_size)
    pending_transactions_list_from_db = Chain.pending_transactions_list()
    id_to_params = id_to_params(pending_transactions_list_from_db)

    with {:ok, responses} <-
           id_to_params
           |> get_transaction_receipt_requests()
           |> Enum.chunk_every(receipts_batch_size)
           |> json_rpc(json_rpc_named_arguments) do
      Enum.each(responses, fn
        %{id: id, result: result} ->
          pending_transaction = Map.fetch!(id_to_params, id)

          if result do
            fetch_block_and_invalidate_wrapper(pending_transaction, to_string(pending_transaction.hash), result)
          else
            Logger.debug(
              "Transaction with hash #{pending_transaction.hash} doesn't exist in the node anymore. We should remove it from Blockscout DB.",
              fetcher: :pending_transactions_to_refetch
            )

            fetch_pending_transaction_and_delete(pending_transaction)
          end

        error ->
          Logger.error("Error while fetching pending transaction receipt: #{inspect(error)}")
      end)
    end

    Logger.debug("Pending transactions are sanitized",
      fetcher: :pending_transactions_to_refetch
    )
  end

  defp get_transaction_receipt_requests(id_to_params) do
    Enum.map(id_to_params, fn {id, transaction} ->
      request(%{id: id, method: "eth_getTransactionReceipt", params: [to_string(transaction.hash)]})
    end)
  end

  defp fetch_block_and_invalidate_wrapper(pending_transaction, pending_transaction_hash_string, result) do
    block_hash = Map.get(result, "blockHash")

    if block_hash do
      Logger.debug(
        "Transaction with hash #{pending_transaction_hash_string} already included into the block #{block_hash}. We should invalidate consensus for it in order to re-fetch transactions",
        fetcher: :pending_transactions_to_refetch
      )

      fetch_block_and_invalidate(block_hash, pending_transaction, result)
    else
      Logger.debug(
        "Transaction with hash #{pending_transaction_hash_string} is still pending. Do nothing.",
        fetcher: :pending_transactions_to_refetch
      )
    end
  end

  defp fetch_pending_transaction_and_delete(transaction) do
    with %{block_hash: nil} <- Repo.reload(transaction),
         changeset = Changeset.change(transaction),
         {:ok, _transaction} <- Repo.delete(changeset, timeout: :infinity) do
      Logger.debug(
        "Transaction with hash #{transaction.hash} successfully deleted from Blockscout DB because it doesn't exist in the archive node anymore",
        fetcher: :pending_transactions_to_refetch
      )
    else
      {:error, changeset} ->
        Logger.debug(
          [
            "Deletion of pending transaction with hash #{transaction.hash} from Blockscout DB failed",
            inspect(changeset)
          ],
          fetcher: :pending_transactions_to_refetch
        )

      _transaction ->
        Logger.debug(
          "Transaction with hash #{transaction.hash} is already included in block, cancel deletion",
          fetcher: :pending_transactions_to_refetch
        )
    end
  end

  defp fetch_block_and_invalidate(block_hash, pending_transaction, transaction) do
    case Chain.fetch_block_by_hash(block_hash) do
      %{number: number, consensus: consensus} = block ->
        Logger.debug(
          "Corresponding number of the block with hash #{block_hash} to invalidate is #{number} and consensus #{consensus}",
          fetcher: :pending_transactions_to_refetch
        )

        invalidate_block(block, pending_transaction, transaction)

      _ ->
        Logger.debug(
          "Block with hash #{block_hash} is not yet in the DB",
          fetcher: :pending_transactions_to_refetch
        )
    end
  end

  defp invalidate_block(block, pending_transaction, transaction) do
    if block.consensus do
      Block.set_refetch_needed(block.number)
    else
      transaction_info = to_elixir(transaction)

      changeset =
        pending_transaction
        |> Transaction.changeset()
        |> Changeset.put_change(:cumulative_gas_used, transaction_info["cumulativeGasUsed"])
        |> Changeset.put_change(:gas_used, transaction_info["gasUsed"])
        |> Changeset.put_change(:index, transaction_info["transactionIndex"])
        |> Changeset.put_change(:block_number, block.number)
        |> Changeset.put_change(:block_hash, block.hash)
        |> Changeset.put_change(:block_timestamp, block.timestamp)
        |> Changeset.put_change(:block_consensus, false)

      Repo.update(changeset)

      Logger.debug(
        "Pending transaction with hash #{pending_transaction.hash} assigned to block ##{block.number} with hash #{block.hash}"
      )
    end
  end
end
