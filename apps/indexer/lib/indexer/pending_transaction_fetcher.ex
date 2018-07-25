defmodule Indexer.PendingTransactionFetcher do
  @moduledoc """
  Fetches pending transactions and imports them.

  *NOTE*: Pending transactions are imported with with `on_conflict: :nothing`, so that they don't overwrite their own
  validated version that may make it to the database first.
  """
  use GenServer

  require Logger

  import EthereumJSONRPC, only: [fetch_pending_transactions: 1]

  alias Explorer.Chain
  alias Indexer.{AddressExtraction, PendingTransactionFetcher}

  # milliseconds
  @default_interval 1_000

  defstruct interval: @default_interval,
            json_rpc_named_arguments: [],
            task: nil

  @gen_server_options ~w(debug name spawn_opt timeout)a

  @doc """
  Starts the pending transaction fetcher.

  ## Options

    * `:debug` - if present, the corresponding function in the [`:sys` module](http://www.erlang.org/doc/man/sys.html)
      is invoked
    * `:name` - used for name registration as described in the "Name registration" section of the `GenServer` module
      documentation
    * `:pending_transaction_interval` - the millisecond time between checking for pending transactions.  Defaults to
      `#{@default_interval}` milliseconds.
    * `:spawn_opt` - if present, its value is passed as options to the underlying process as in `Process.spawn/4`
    * `:json_rpc_named_arguments` - `t:EthereumJSONRPC.json_rpc_named_arguments/0` passed to
      `EthereumJSONRPC.json_rpc/2`.
    * `:timeout` - if present, the server is allowed to spend the given number of milliseconds initializing or it will
      be terminated and the start function will return `{:error, :timeout}`

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, Keyword.drop(opts, @gen_server_options), Keyword.take(opts, @gen_server_options))
  end

  @impl GenServer
  def init(opts) do
    opts =
      :indexer
      |> Application.get_all_env()
      |> Keyword.merge(opts)

    state =
      %PendingTransactionFetcher{
        json_rpc_named_arguments: Keyword.fetch!(opts, :json_rpc_named_arguments),
        interval: opts[:pending_transaction_interval] || @default_interval
      }
      |> schedule_fetch()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:fetch, %PendingTransactionFetcher{} = state) do
    task = Task.Supervisor.async_nolink(Indexer.TaskSupervisor, fn -> task(state) end)
    {:noreply, %PendingTransactionFetcher{state | task: task}}
  end

  def handle_info({ref, _}, %PendingTransactionFetcher{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])

    {:noreply, schedule_fetch(state)}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %PendingTransactionFetcher{task: %Task{pid: pid, ref: ref}} = state
      ) do
    Logger.error(fn -> "pending transaction fetcher task exited due to #{inspect(reason)}.  Rescheduling." end)

    {:noreply, schedule_fetch(state)}
  end

  defp schedule_fetch(%PendingTransactionFetcher{interval: interval} = state) do
    Process.send_after(self(), :fetch, interval)
    %PendingTransactionFetcher{state | task: nil}
  end

  defp task(%PendingTransactionFetcher{json_rpc_named_arguments: json_rpc_named_arguments} = _state) do
    case fetch_pending_transactions(json_rpc_named_arguments) do
      {:ok, transactions_params} ->
        addresses_params = AddressExtraction.extract_addresses(%{transactions: transactions_params}, pending: true)

        # There's no need to queue up fetching the address balance since theses are pending transactions and cannot have
        # affected the address balance yet since address balance is a balance at a give block and these transactions are
        # blockless.
        {:ok, _} =
          Chain.import_blocks(
            addresses: [params: addresses_params],
            transactions: [on_conflict: :nothing, params: transactions_params]
          )

      :ignore ->
        :ok
    end
  end
end
