defmodule Indexer.Fetcher.PendingTransaction do
  @moduledoc """
  Fetches pending transactions and imports them.

  *NOTE*: Pending transactions are imported with with `on_conflict: :nothing`, so that they don't overwrite their own
  validated version that may make it to the database first.
  """
  use GenServer
  use Indexer.Fetcher, restart: :permanent

  require Logger

  import EthereumJSONRPC, only: [fetch_pending_transactions: 1]

  alias Ecto.Changeset
  alias Explorer.Chain
  alias Explorer.Chain.Cache.Accounts
  alias Indexer.Fetcher.PendingTransaction
  alias Indexer.Transform.Addresses

  @chunk_size 100

  # milliseconds
  @default_interval 1_000

  defstruct interval: @default_interval,
            json_rpc_named_arguments: [],
            last_fetch_at: nil,
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
      %__MODULE__{
        json_rpc_named_arguments: Keyword.fetch!(opts, :json_rpc_named_arguments),
        interval: opts[:pending_transaction_interval] || @default_interval
      }
      |> schedule_fetch()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:fetch, %__MODULE__{} = state) do
    task = Task.Supervisor.async_nolink(PendingTransaction.TaskSupervisor, fn -> task(state) end)
    {:noreply, %__MODULE__{state | task: task}}
  end

  def handle_info({ref, result}, %__MODULE__{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, new_last_fetch_at} ->
        {:noreply, schedule_fetch(%{state | last_fetch_at: new_last_fetch_at})}

      _ ->
        {:noreply, schedule_fetch(state)}
    end
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %__MODULE__{task: %Task{pid: pid, ref: ref}} = state
      ) do
    Logger.error(fn -> "pending transaction fetcher task exited due to #{inspect(reason)}.  Rescheduling." end)

    {:noreply, schedule_fetch(state)}
  end

  defp schedule_fetch(%__MODULE__{interval: interval} = state) do
    Process.send_after(self(), :fetch, interval)
    %__MODULE__{state | task: nil}
  end

  defp task(%__MODULE__{json_rpc_named_arguments: json_rpc_named_arguments} = _state) do
    Logger.metadata(fetcher: :pending_transaction)

    case fetch_pending_transactions(json_rpc_named_arguments) do
      {:ok, transactions_params} ->
        new_last_fetched_at = NaiveDateTime.utc_now()

        transactions_params
        |> Stream.map(&Map.put(&1, :earliest_processing_start, new_last_fetched_at))
        |> Stream.chunk_every(@chunk_size)
        |> Enum.each(&import_chunk/1)

        {:ok, new_last_fetched_at}

      :ignore ->
        :ok

      {:error, :timeout} ->
        Logger.error("timeout")

        :ok

      {:error, :etimedout} ->
        Logger.error("timeout")

        :ok

      {:error, :econnrefused} ->
        Logger.error("connection_refused")

        :ok

      {:error, {:bad_gateway, _}} ->
        Logger.error("bad_gateway")

        :ok

      {:error, :closed} ->
        Logger.error("closed")

        :ok

      {:error, reason} ->
        Logger.error(inspect(reason))

        :ok
    end
  end

  defp import_chunk(transactions_params) do
    addresses_params = Addresses.extract_addresses(%{transactions: transactions_params}, pending: true)

    # There's no need to queue up fetching the address balance since theses are pending transactions and cannot have
    # affected the address balance yet since address balance is a balance at a given block and these transactions are
    # blockless.
    case Chain.import(%{
           addresses: %{params: addresses_params, on_conflict: :nothing},
           broadcast: :realtime,
           transactions: %{params: transactions_params, on_conflict: :nothing}
         }) do
      {:ok, imported} ->
        Accounts.drop(imported[:addresses])
        :ok

      {:error, [%Changeset{} | _] = changesets} ->
        Logger.error(fn -> ["Failed to validate: ", inspect(changesets)] end, step: :import)
        :ok

      {:error, reason} ->
        Logger.error(fn -> inspect(reason) end, step: :import)

      {:error, step, failed_value, _changes_so_far} ->
        Logger.error(fn -> ["Failed to import: ", inspect(failed_value)] end, step: step)
        :ok
    end
  end
end
