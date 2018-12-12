defmodule Indexer.PendingTransaction.Fetcher do
  @moduledoc """
  Fetches pending transactions and imports them.

  *NOTE*: Pending transactions are imported with with `on_conflict: :nothing`, so that they don't overwrite their own
  validated version that may make it to the database first.
  """
  use GenServer

  require Logger

  import EthereumJSONRPC, only: [fetch_pending_transactions: 1]

  alias Explorer.Chain
  alias Indexer.{AddressExtraction, PendingTransaction}

  # milliseconds
  @default_interval 1_000

  defstruct interval: @default_interval,
            json_rpc_named_arguments: [],
            task: nil

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
  def start_link(arguments, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl GenServer
  def init(opts) when is_list(opts) do
    Logger.metadata(fetcher: :pending_transaction)

    opts =
      :indexer
      |> Application.get_all_env()
      |> Keyword.merge(opts)

    state =
      %PendingTransaction.Fetcher{
        json_rpc_named_arguments: Keyword.fetch!(opts, :json_rpc_named_arguments),
        interval: opts[:pending_transaction_interval] || @default_interval
      }
      |> schedule_fetch()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:fetch, %PendingTransaction.Fetcher{} = state) do
    task = Task.Supervisor.async_nolink(PendingTransaction.TaskSupervisor, fn -> task(state) end)
    {:noreply, %PendingTransaction.Fetcher{state | task: task}}
  end

  def handle_info({ref, _}, %PendingTransaction.Fetcher{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])

    {:noreply, schedule_fetch(state)}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %PendingTransaction.Fetcher{task: %Task{pid: pid, ref: ref}} = state
      ) do
    Logger.error(fn -> "pending transaction fetcher task exited due to #{inspect(reason)}.  Rescheduling." end)

    {:noreply, schedule_fetch(state)}
  end

  defp schedule_fetch(%PendingTransaction.Fetcher{interval: interval} = state) do
    Process.send_after(self(), :fetch, interval)
    %PendingTransaction.Fetcher{state | task: nil}
  end

  defp task(%PendingTransaction.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = _state) do
    Logger.metadata(fetcher: :pending_transaction)

    case fetch_pending_transactions(json_rpc_named_arguments) do
      {:ok, transactions_params} ->
        addresses_params = AddressExtraction.extract_addresses(%{transactions: transactions_params}, pending: true)

        # There's no need to queue up fetching the address balance since theses are pending transactions and cannot have
        # affected the address balance yet since address balance is a balance at a give block and these transactions are
        # blockless.
        {:ok, _} =
          Chain.import(%{
            addresses: %{params: addresses_params},
            broadcast: :realtime,
            transactions: %{params: transactions_params, on_conflict: :nothing}
          })

      :ignore ->
        :ok
    end
  end
end
