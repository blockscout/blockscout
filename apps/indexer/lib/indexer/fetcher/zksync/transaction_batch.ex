defmodule Indexer.Fetcher.ZkSync.TransactionBatch do
  @moduledoc """
    Discovers new batches and populates the `zksync_transaction_batches` table.

    Repetitiveness is supported by sending a `:continue` message to itself every `recheck_interval` seconds.

    Each iteration compares the number of the last handled batch stored in the state with the
    latest batch available on the RPC node. If the rollup progresses, all batches between the
    last handled batch (exclusively) and the latest available batch (inclusively) are downloaded from RPC
    in chunks of `chunk_size` and imported into the `zksync_transaction_batches` table. If the latest
    available batch is too far from the last handled batch, only `batches_max_range` batches are downloaded.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain.ZkSync.Reader
  alias Indexer.Fetcher.ZkSync.Discovery.Workers
  alias Indexer.Fetcher.ZkSync.Utils.Rpc

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1]

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(args) do
    Logger.metadata(fetcher: :zksync_transaction_batches)

    config = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.TransactionBatch]
    chunk_size = config[:chunk_size]
    recheck_interval = config[:recheck_interval]
    batches_max_range = config[:batches_max_range]

    Process.send(self(), :init, [])

    {:ok,
     %{
       config: %{
         chunk_size: chunk_size,
         batches_max_range: batches_max_range,
         json_rpc_named_arguments: args[:json_rpc_named_arguments],
         recheck_interval: recheck_interval
       },
       data: %{latest_handled_batch_number: 0}
     }}
  end

  @impl GenServer
  def handle_info(:init, state) do
    latest_handled_batch_number =
      case Reader.latest_available_batch_number() do
        nil ->
          log_info("No batches found in DB. Will start with the latest batch available by RPC")
          # The value received from RPC is decremented in order to not waste
          # the first iteration of handling `:continue` message.
          Rpc.fetch_latest_sealed_batch_number(state.config.json_rpc_named_arguments) - 1

        latest_handled_batch_number ->
          latest_handled_batch_number
      end

    Process.send_after(self(), :continue, 2000)

    log_info("All batches including #{latest_handled_batch_number} are considered as handled")

    {:noreply, %{state | data: %{latest_handled_batch_number: latest_handled_batch_number}}}
  end

  # Checks if the rollup progresses by comparing the recently stored batch
  # with the latest batch received from RPC. If progress is detected, it downloads
  # batches, builds their associations with rollup blocks and transactions, and
  # imports the received data to the database. If the latest batch received from RPC
  # is too far from the most recently stored batch, only `batches_max_range` batches
  # are downloaded. All RPC calls to get batch details and receive transactions
  # included in batches are made in chunks of `chunk_size`.
  #
  # After importing batch information, it schedules the next iteration by sending
  # the `:continue` message. The sending of the message is delayed, taking into account
  # the time remaining after downloading and importing processes.
  #
  # ## Parameters
  # - `:continue`: The message triggering the handler.
  # - `state`: The current state of the fetcher containing both the fetcher configuration
  #            and the latest handled batch number.
  #
  # ## Returns
  # - `{:noreply, new_state}` where the latest handled batch number is updated with the largest
  #   of the batch numbers imported in the current iteration.
  @impl GenServer
  def handle_info(
        :continue,
        %{
          data: %{latest_handled_batch_number: latest_handled_batch_number},
          config: %{
            batches_max_range: batches_max_range,
            json_rpc_named_arguments: json_rpc_named_arguments,
            recheck_interval: recheck_interval,
            chunk_size: _
          }
        } = state
      ) do
    log_info("Checking for a new batch or batches")

    latest_sealed_batch_number = Rpc.fetch_latest_sealed_batch_number(json_rpc_named_arguments)

    {new_state, handle_duration} =
      if latest_handled_batch_number < latest_sealed_batch_number do
        start_batch_number = latest_handled_batch_number + 1
        end_batch_number = min(latest_sealed_batch_number, latest_handled_batch_number + batches_max_range)

        log_info("Handling the batch range #{start_batch_number}..#{end_batch_number}")

        {handle_duration, _} =
          :timer.tc(&Workers.get_minimal_batches_info_and_import/3, [start_batch_number, end_batch_number, state.config])

        {
          %{state | data: %{latest_handled_batch_number: end_batch_number}},
          div(handle_duration, 1000)
        }
      else
        {state, 0}
      end

    Process.send_after(self(), :continue, max(:timer.seconds(recheck_interval) - handle_duration, 0))

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end
end
