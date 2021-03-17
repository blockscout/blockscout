defmodule Indexer.PendingTransactionsSanitizer do
  @moduledoc """
  Periodically checks pending transactions status in order to detect that transaction already included to the block
  And we need to re-fetch that block.
  """

  use GenServer

  require Logger

  import EthereumJSONRPC, only: [json_rpc: 2, request: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Import.Runner.Blocks

  @interval :timer.hours(3)

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

          Logger.debug(
            "Transaction #{pending_tx_hash_str} already included into the block #{block_hash}. We should invalidate consensus for it in order to re-fetch transactions",
            fetcher: :pending_transactions_to_refetch
          )

          fetch_block_and_invalidate(block_hash)
        end
      end
    end)

    Logger.debug("Pending transactions are sanitized",
      fetcher: :pending_transactions_to_refetch
    )
  end

  defp fetch_block_and_invalidate(block_hash) do
    case Chain.fetch_block_by_hash(block_hash) do
      %{number: number, consensus: consensus} ->
        Logger.debug(
          "Corresponding number of the block with hash #{block_hash} to invalidate is #{number} and consensus #{
            consensus
          }",
          fetcher: :pending_transactions_to_refetch
        )

        invalidate_block(number, consensus)

      _ ->
        Logger.debug(
          "Block with hash #{block_hash} is not yet in the DB",
          fetcher: :pending_transactions_to_refetch
        )
    end
  end

  defp invalidate_block(number, consensus) do
    if consensus do
      opts = %{
        timeout: 60_000,
        timestamps: %{updated_at: DateTime.utc_now()}
      }

      Blocks.lose_consensus(Repo, [], [number], [], opts)
    end
  end
end
