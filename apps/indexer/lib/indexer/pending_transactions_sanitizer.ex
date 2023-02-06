defmodule Indexer.PendingTransactionsSanitizer do
  @moduledoc """
  Periodically checks pending transactions status in order to detect that transaction already included to the block
  And we need to re-fetch that block.
  """

  use GenServer

  require Logger

  import EthereumJSONRPC, only: [json_rpc: 2, request: 1]
  import EthereumJSONRPC.Receipt, only: [to_elixir: 1]

  alias Ecto.Changeset
  alias Explorer.Celo.Telemetry
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Hash.Full, as: Hash
  alias Explorer.Chain.Import.Runner.Blocks
  alias Explorer.Chain.Transaction

  @interval :timer.minutes(10)

  defstruct interval: @interval,
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
      interval: opts[:interval] || @interval
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
    Telemetry.event(:pending_transactions_sanitize)

    pending_transactions_list_from_db = Chain.pending_transactions_list()

    pending_transactions_list_from_db
    |> Enum.with_index()
    |> Enum.each(fn {pending_tx, ind} ->
      pending_tx_hash_str = "0x" <> Base.encode16(pending_tx.hash.bytes, case: :lower)

      with {:ok, result} <-
             %{id: ind, method: "eth_getTransactionReceipt", params: [pending_tx_hash_str]}
             |> request()
             |> json_rpc(json_rpc_named_arguments) do
        if result do
          block_hash = Map.get(result, "blockHash")

          if block_hash do
            Logger.debug(
              "Transaction with hash #{pending_tx_hash_str} already included into the block #{block_hash}. We should invalidate consensus for it in order to re-fetch transactions",
              fetcher: :pending_transactions_to_refetch
            )

            fetch_block_and_invalidate(block_hash, pending_tx, result)
          else
            Logger.debug(
              "Transaction with hash #{pending_tx_hash_str} is still pending. Do nothing.",
              fetcher: :pending_transactions_to_refetch
            )
          end
        else
          Logger.debug(
            "Transaction with hash #{pending_tx_hash_str} doesn't exist in the node anymore. We should remove it from Blockscout DB.",
            fetcher: :pending_transactions_to_refetch
          )

          fetch_pending_transaction_and_delete(pending_tx)
        end
      end
    end)

    Logger.debug("Pending transactions are sanitized",
      fetcher: :pending_transactions_to_refetch
    )
  end

  defp fetch_pending_transaction_and_delete(transaction) do
    pending_tx_hash_str = "0x" <> Base.encode16(transaction.hash.bytes, case: :lower)

    case transaction
         |> Changeset.change()
         |> Repo.delete() do
      {:ok, _transaction} ->
        Logger.debug(
          "Transaction with hash #{pending_tx_hash_str} successfully deleted from Blockscout DB because it doesn't exist in the archive node anymore",
          fetcher: :pending_transactions_to_refetch
        )

      {:error, changeset} ->
        Logger.debug(
          [
            "Deletion of pending transaction with hash #{pending_tx_hash_str} from Blockscout DB failed",
            inspect(changeset)
          ],
          fetcher: :pending_transactions_to_refetch
        )
    end
  end

  defp fetch_block_and_invalidate(block_hash, pending_tx, tx) do
    case Chain.fetch_block_by_hash(block_hash) do
      %{number: number, consensus: consensus} ->
        Logger.debug(
          "Corresponding number of the block with hash #{block_hash} to invalidate is #{number} and consensus #{consensus}",
          fetcher: :pending_transactions_to_refetch
        )

        invalidate_block(number, block_hash, consensus, pending_tx, tx)

      _ ->
        Logger.debug(
          "Block with hash #{block_hash} is not yet in the DB",
          fetcher: :pending_transactions_to_refetch
        )
    end
  end

  defp invalidate_block(block_number, block_hash, consensus, pending_tx, tx) do
    if consensus do
      Blocks.invalidate_consensus_blocks([block_number])
    else
      {:ok, hash} = Hash.cast(block_hash)
      tx_info = to_elixir(tx)

      changeset =
        pending_tx
        |> Transaction.changeset()
        |> Changeset.put_change(:cumulative_gas_used, tx_info["cumulativeGasUsed"])
        |> Changeset.put_change(:gas_used, tx_info["gasUsed"])
        |> Changeset.put_change(:index, tx_info["transactionIndex"])
        |> Changeset.put_change(:block_number, block_number)
        |> Changeset.put_change(:block_hash, hash)

      Repo.update(changeset)

      Logger.debug(
        "Pending tx with hash #{"0x" <> Base.encode16(pending_tx.hash.bytes, case: :lower)} assigned to block ##{block_number} with hash #{block_hash}"
      )
    end
  end
end
