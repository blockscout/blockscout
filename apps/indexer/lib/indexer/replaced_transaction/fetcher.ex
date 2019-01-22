defmodule Indexer.ReplacedTransaction.Fetcher do
  @moduledoc """
  A transaction can get dropped and replaced when a newly created transaction with the same `FROM`
  account nonce is accepted and confirmed by the network.
  And because it has the same account nonce as the previous transaction it replaces the previous txhash.

  This fetcher finds these transaction and sets them `failed` status with `dropped/replaced` error.
  """
  use GenServer

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Transaction
  alias Explorer.Repo
  alias Indexer.ReplacedTransaction

  # 30 minutes
  @default_interval 60_000 * 30

  # 60 seconds
  @query_timeout 60_000

  defstruct interval: @default_interval,
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
        interval: opts[:pending_transaction_interval] || @default_interval
      }
      |> schedule_find()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:find, %__MODULE__{} = state) do
    task = Task.Supervisor.async_nolink(ReplacedTransaction.TaskSupervisor, fn -> task() end)
    {:noreply, %__MODULE__{state | task: task}}
  end

  def handle_info({ref, _}, %__MODULE__{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])

    {:noreply, schedule_find(state)}
  end

  def handle_info(
        {:DOWN, ref, :process, pid, reason},
        %__MODULE__{task: %Task{pid: pid, ref: ref}} = state
      ) do
    Logger.error(fn -> "replaced transaction finder task exited due to #{inspect(reason)}.  Rescheduling." end)

    {:noreply, schedule_find(state)}
  end

  defp schedule_find(%__MODULE__{interval: interval} = state) do
    Process.send_after(self(), :find, interval)
    %__MODULE__{state | task: nil}
  end

  defp task do
    Logger.metadata(fetcher: :replaced_transaction)

    query =
      from(transaction in Transaction,
        where: is_nil(transaction.block_number),
        join: mined_transaction in Transaction,
        where:
          transaction.from_address_hash == mined_transaction.from_address_hash and
            transaction.nonce == mined_transaction.nonce and not is_nil(mined_transaction.block_number),
        update: [
          set: [status: ^:error, error: "dropped/replaced"]
        ]
      )

    try do
      Repo.update_all(query, [], timeout: @query_timeout)
    rescue
      error ->
        Logger.error(fn -> ["Failed to make pending transactions dropped: ", inspect(error)] end)
    end
  end
end
