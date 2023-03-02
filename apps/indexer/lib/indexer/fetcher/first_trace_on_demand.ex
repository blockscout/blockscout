defmodule Indexer.Fetcher.FirstTraceOnDemand do
  @moduledoc """
    On demand fetcher of first transaction's trace
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  alias Explorer.Chain
  alias Explorer.Chain.Import
  alias Explorer.Chain.Import.Runner.InternalTransactions

  require Logger

  def trigger_fetch(transaction) do
    GenServer.cast(__MODULE__, {:fetch, transaction})
  end

  def fetch_first_trace(transaction, state) do
    hash_string = to_string(transaction.hash)

    response =
      Chain.fetch_first_trace(
        [
          %{
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            hash_data: hash_string,
            transaction_index: transaction.index
          }
        ],
        state.json_rpc_named_arguments
      )

    case response do
      {:ok, first_trace_params} ->
        InternalTransactions.run_insert_only(first_trace_params, %{
          timeout: :infinity,
          timestamps: Import.timestamps(),
          internal_transactions: %{params: first_trace_params}
        })

      {:error, reason} ->
        Logger.error(fn ->
          ["Error while fetching first trace for tx: #{hash_string} error reason: ", reason]
        end)

      :ignore ->
        :ignore
    end
  end

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl true
  def init(json_rpc_named_arguments) do
    {:ok, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  @impl true
  def handle_cast({:fetch, transaction}, state) do
    fetch_first_trace(transaction, state)

    {:noreply, state}
  end
end
