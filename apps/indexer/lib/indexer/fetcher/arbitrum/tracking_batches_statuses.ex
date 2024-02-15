defmodule Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses do
  @moduledoc """
  TBD
  """

  use GenServer
  use Indexer.Fetcher

  alias Indexer.Fetcher.Arbitrum.Workers.{L1Finalization, NewBatches}

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [increase_duration: 2]

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}

  require Logger

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
    Logger.metadata(fetcher: :arbitrum_batches_tracker)

    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    l1_rpc = config_common[:l1_rpc]
    l1_rpc_block_range = config_common[:l1_rpc_block_range]
    l1_rollup_address = config_common[:l1_rollup_address]
    l1_start_block = config_common[:l1_start_block]
    l1_rpc_chunk_size = config_common[:l1_rpc_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]
    messages_to_blocks_shift = config_tracker[:messages_to_blocks_shift]
    track_l1_tx_finalization = config_tracker[:track_l1_tx_finalization]

    Process.send(self(), :init_worker, [])

    {:ok,
     %{
       config: %{
         json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
         json_l1_rpc_named_arguments: IndexerHelper.build_json_rpc_named_arguments(l1_rpc),
         l1_rpc_chunk_size: l1_rpc_chunk_size,
         recheck_interval: recheck_interval,
         l1_rpc_block_range: l1_rpc_block_range,
         l1_rollup_address: l1_rollup_address,
         l1_start_block: l1_start_block,
         messages_to_blocks_shift: messages_to_blocks_shift,
         track_l1_tx_finalization: track_l1_tx_finalization
       },
       data: %{}
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # TBD
  @impl GenServer
  def handle_info(:init_worker, state) do
    %{outbox: outbox_address, sequencer_inbox: sequencer_inbox_address} =
      Rpc.get_contracts_for_rollup(
        state.config.l1_rollup_address,
        :inbox_outbox,
        state.config.json_l1_rpc_named_arguments
      )

    new_batches_start_block = Db.l1_block_of_latest_committed_batch(state.config.l1_start_block)

    new_confirmations_start_block = state.config.l1_start_block

    Process.send(self(), :check_new_batches, [])

    new_state =
      state
      |> Map.put(
        :config,
        Map.merge(state.config, %{
          l1_outbox_address: outbox_address,
          l1_sequencer_inbox_address: sequencer_inbox_address
        })
      )
      |> Map.put(
        :data,
        Map.merge(state.data, %{
          new_batches_start_block: new_batches_start_block,
          new_confirmations_start_block: new_confirmations_start_block
        })
      )

    {:noreply, new_state}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_new_batches, state) do
    {handle_duration, {:ok, end_block}} =
      :timer.tc(&discover_new_batches/1, [
        state
      ])

    # {handle_duration, _} =
    #   :timer.tc(&nothing_to_do/1, [
    #     state
    #   ])

    # end_block = 0

    Process.send(self(), :check_new_confirmations, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        new_batches_start_block: end_block + 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_new_confirmations, state) do
    {handle_duration, _} =
      :timer.tc(&nothing_to_do/1, [
        state
      ])

    Process.send(self(), :check_lifecycle_txs_finalization, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration)
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_lifecycle_txs_finalization, state) do
    {handle_duration, _} =
      if state.config.track_l1_tx_finalization do
        :timer.tc(&monitor_lifecycle_txs_finalization/1, [
          state
        ])
      else
        {0, nil}
      end

    Process.send_after(
      self(),
      :check_new_batches,
      max(:timer.seconds(state.config.recheck_interval) - div(increase_duration(state.data, handle_duration), 1000), 0)
    )

    new_data =
      Map.merge(state.data, %{
        duration: 0
      })

    {:noreply, %{state | data: new_data}}
  end

  def discover_new_batches(
        %{
          config: %{
            json_l1_rpc_named_arguments: json_rpc_named_arguments,
            l1_rpc_chunk_size: chunk_size,
            l1_rpc_block_range: rpc_block_range,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            track_l1_tx_finalization: track_l1_finalization?
          },
          data: %{new_batches_start_block: start_block}
        } = _state
      ) do
    # Requesting the "latest" block instead of "safe" allows to catch new batches
    # without latency.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + rpc_block_range - 1, latest_block)

    if start_block <= end_block do
      Logger.info("Block range for new batches discovery: #{start_block}..#{end_block}")

      NewBatches.discover(
        sequencer_inbox_address,
        start_block,
        end_block,
        messages_to_blocks_shift,
        json_rpc_named_arguments,
        chunk_size,
        track_l1_finalization?
      )

      {:ok, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  defp monitor_lifecycle_txs_finalization(state) do
    L1Finalization.monitor_lifecycle_txs(state.config.json_l1_rpc_named_arguments)
  end

  defp nothing_to_do(_) do
    :timer.sleep(500)
  end
end
