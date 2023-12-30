defmodule Indexer.Fetcher.ZkSync.TransactionBatch do
  @moduledoc """
    Discovers new batches and fills zksync_transaction_batches DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain.ZkSync.Reader
  alias Indexer.Fetcher.ZkSync.Utils.Rpc
  alias Indexer.Fetcher.ZkSync.Utils.Db
  alias Indexer.Fetcher.ZkSync.Discovery.BatchesData

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
      cond do
        latest_handled_batch_number = Reader.latest_available_batch_number() ->
          latest_handled_batch_number - 1

        true ->
          log_info("No batches found in DB")
          Rpc.fetch_latest_sealed_batch_number(state.config.json_rpc_named_arguments) - 1
      end

    Process.send_after(self(), :continue, 2000)

    log_info("The latest unfinalized batch number #{latest_handled_batch_number}")

    {:noreply, %{state | data: %{latest_handled_batch_number: latest_handled_batch_number}}}
  end

  @impl GenServer
  def handle_info(:continue, state) do
    %{
      data: %{latest_handled_batch_number: latest_handled_batch_number},
      config: %{
        batches_max_range: batches_max_range,
        json_rpc_named_arguments: json_rpc_named_arguments,
        recheck_interval: recheck_interval
      }
    } = state

    latest_sealed_batch_number = Rpc.fetch_latest_sealed_batch_number(json_rpc_named_arguments)

    log_info("Checking for a new batch")

    {new_state, handle_duration} =
      if latest_handled_batch_number < latest_sealed_batch_number do
        start_batch_number = latest_handled_batch_number + 1
        end_batch_number = min(latest_sealed_batch_number, latest_handled_batch_number + batches_max_range)

        log_info("Handling the batch range #{start_batch_number}..#{end_batch_number}")

        {handle_duration, _} = :timer.tc(&handle_batch_range/3, [start_batch_number, end_batch_number, state.config])

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

  defp handle_batch_range(start_batch_number, end_batch_number, config) do
    {batches_to_import, l2_blocks_to_import, l2_txs_to_import} =
      BatchesData.extract_data_from_batches(start_batch_number, end_batch_number, config)

    batches_list_to_import =
      Map.values(batches_to_import)
      |> Enum.reduce([], fn batch, batches_list ->
        [Db.prune_json_batch(batch) | batches_list]
      end)

    Db.import_to_db(
      batches_list_to_import,
      [],
      l2_txs_to_import,
      l2_blocks_to_import
    )
  end
end
