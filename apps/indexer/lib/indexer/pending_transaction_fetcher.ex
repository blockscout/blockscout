defmodule Indexer.PendingTransactionFetcher do
  @moduledoc """
  Fetches pending transactions and imports them.

  *NOTE*: Pending transactions are imported with with `on_conflict: :nothing`, so that they don't overwrite their own
  validated version that may make it to the database first.
  """
  use GenServer

  require Logger

  import EthereumJSONRPC.Parity, only: [fetch_pending_transactions: 0]

  alias Explorer.Chain
  alias Indexer.{AddressExtraction, PendingTransactionFetcher}

  # milliseconds
  @default_interval 1_000

  defstruct interval: @default_interval,
            task_ref: nil,
            task_pid: nil

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
      %PendingTransactionFetcher{interval: opts[:pending_transaction_interval] || @default_interval}
      |> schedule_fetch()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:fetch, %PendingTransactionFetcher{} = state) do
    {:ok, pid, ref} = Indexer.start_monitor(fn -> task(state) end)
    {:noreply, %PendingTransactionFetcher{state | task_ref: ref, task_pid: pid}}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %PendingTransactionFetcher{task_ref: ref, task_pid: pid} = state) do
    case reason do
      :normal ->
        :ok

      _ ->
        Logger.error(fn -> "pending transaction fetcher task exited due to #{inspect(reason)}.  Rescheduling." end)
    end

    new_state =
      %PendingTransactionFetcher{state | task_ref: nil, task_pid: nil}
      |> schedule_fetch()

    {:noreply, new_state}
  end

  defp schedule_fetch(%PendingTransactionFetcher{interval: interval} = state) do
    Process.send_after(self(), :fetch, interval)
    state
  end

  defp task(%PendingTransactionFetcher{} = _state) do
    {:ok, transactions_params} = fetch_pending_transactions()

    addresses_params = AddressExtraction.extract_addresses(%{transactions: transactions_params}, pending: true)

    # There's no need to queue up fetching the address balance since theses are pending transactions and cannot have
    # affected the address balance yet since address balance is a balance at a give block and these transactions are
    # blockless.
    {:ok, _} =
      Chain.import_blocks(
        addresses: [params: addresses_params],
        transactions: [on_conflict: :nothing, params: transactions_params]
      )
  end
end
