defmodule Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses do
  @moduledoc """
  TBD
  """

  use GenServer
  use Indexer.Fetcher

  alias Indexer.Fetcher.Arbitrum.Workers.{L1Finalization, NewBatches, NewConfirmations, NewL1Executions}

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
    l1_rollup_init_block = config_common[:l1_rollup_init_block]
    l1_start_block = max(config_common[:l1_start_block], l1_rollup_init_block)
    l1_rpc_chunk_size = config_common[:l1_rpc_chunk_size]
    rollup_chunk_size = config_common[:rollup_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]
    messages_to_blocks_shift = config_tracker[:messages_to_blocks_shift]
    track_l1_tx_finalization = config_tracker[:track_l1_tx_finalization]
    finalized_confirmations = config_tracker[:finalized_confirmations]
    confirmation_batches_depth = config_tracker[:confirmation_batches_depth]
    new_batches_limit = config_tracker[:new_batches_limit]

    Process.send(self(), :init_worker, [])

    {:ok,
     %{
       config: %{
         l1_rpc: %{
           json_rpc_named_arguments: IndexerHelper.build_json_rpc_named_arguments(l1_rpc),
           logs_block_range: l1_rpc_block_range,
           chunk_size: l1_rpc_chunk_size,
           track_finalization: track_l1_tx_finalization,
           finalized_confirmations: finalized_confirmations
         },
         rollup_rpc: %{
           json_rpc_named_arguments: args[:json_rpc_named_arguments],
           chunk_size: rollup_chunk_size
         },
         recheck_interval: recheck_interval,
         l1_rollup_address: l1_rollup_address,
         l1_start_block: l1_start_block,
         l1_rollup_init_block: l1_rollup_init_block,
         new_batches_limit: new_batches_limit,
         messages_to_blocks_shift: messages_to_blocks_shift,
         confirmation_batches_depth: confirmation_batches_depth,
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
  def handle_info(
        :init_worker,
        %{
          config: %{
            l1_rpc: %{json_rpc_named_arguments: json_l1_rpc_named_arguments},
            l1_rollup_address: l1_rollup_address,
            l1_start_block: l1_start_block
          }
        } = state
      ) do
    %{outbox: outbox_address, sequencer_inbox: sequencer_inbox_address} =
      Rpc.get_contracts_for_rollup(
        l1_rollup_address,
        :inbox_outbox,
        json_l1_rpc_named_arguments
      )

    # TODO: it is necessary to develop a way to discover missed batches to cover the case
    #       when the batch #1, #2 and #4 are in DB, but #3 is not
    #       One of the approaches is to look deeper than the latest committed batch and
    #       check whether batches were already handled or not.
    new_batches_start_block = Db.l1_block_to_discover_latest_committed_batch(l1_start_block)
    historical_batches_end_block = Db.l1_block_to_discover_earliest_committed_batch(l1_start_block - 1)

    new_confirmations_start_block = Db.l1_block_of_latest_confirmed_block(l1_start_block)

    # TODO: it is necessary to develop a way to discover missed executions.
    #       One of the approaches is to look deeper than the latest execution and
    #       check whether executions were already handled or not.
    new_executions_start_block = Db.l1_block_to_discover_latest_execution(l1_start_block)
    historical_executions_end_block = Db.l1_block_to_discover_earliest_execution(l1_start_block - 1)

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
          historical_batches_end_block: historical_batches_end_block,
          new_confirmations_start_block: new_confirmations_start_block,
          historical_confirmations_end_block: nil,
          historical_confirmations_start_block: nil,
          new_executions_start_block: new_executions_start_block,
          historical_executions_end_block: historical_executions_end_block
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
    {handle_duration, {retcode, end_block}} =
      :timer.tc(&discover_new_rollup_confirmation/1, [
        state
      ])

    Process.send(self(), :check_new_executions, [])

    updated_fields =
      case retcode do
        :ok -> %{}
        _ -> %{historical_confirmations_end_block: nil, historical_confirmations_start_block: nil}
      end
      |> Map.merge(%{
        # credo:disable-for-previous-line Credo.Check.Refactor.PipeChainStart
        duration: increase_duration(state.data, handle_duration),
        new_confirmations_start_block: end_block + 1
      })

    new_data = Map.merge(state.data, updated_fields)

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_new_executions, state) do
    {handle_duration, {:ok, end_block}} =
      :timer.tc(&discover_new_l1_messages_executions/1, [
        state
      ])

    Process.send(self(), :check_historical_batches, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        new_executions_start_block: end_block + 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_historical_batches, state) do
    {handle_duration, {:ok, start_block}} =
      :timer.tc(&discover_historical_batches/1, [
        state
      ])

    Process.send(self(), :check_historical_confirmations, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        historical_batches_end_block: start_block - 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_historical_confirmations, state) do
    {handle_duration, {retcode, {start_block, end_block}}} =
      :timer.tc(&discover_historical_rollup_confirmation/1, [
        state
      ])

    Process.send(self(), :check_historical_executions, [])

    updated_fields =
      case retcode do
        :ok -> %{historical_confirmations_end_block: start_block - 1, historical_confirmations_start_block: end_block}
        _ -> %{historical_confirmations_end_block: nil, historical_confirmations_start_block: nil}
      end
      |> Map.merge(%{
        # credo:disable-for-previous-line Credo.Check.Refactor.PipeChainStart
        duration: increase_duration(state.data, handle_duration)
      })

    new_data = Map.merge(state.data, updated_fields)

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_historical_executions, state) do
    {handle_duration, {:ok, start_block}} =
      :timer.tc(&discover_historical_l1_messages_executions/1, [
        state
      ])

    Process.send(self(), :check_lifecycle_txs_finalization, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        historical_executions_end_block: start_block - 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # TBD
  @impl GenServer
  def handle_info(:check_lifecycle_txs_finalization, state) do
    {handle_duration, _} =
      if state.config.l1_rpc.track_finalization do
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
            l1_rpc: l1_rpc_config,
            rollup_rpc: rollup_rpc_config,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            new_batches_limit: new_batches_limit
          },
          data: %{new_batches_start_block: start_block}
        } = _state
      ) do
    # Requesting the "latest" block instead of "safe" allows to catch new batches
    # without latency.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        l1_rpc_config.json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + l1_rpc_config.logs_block_range - 1, latest_block)

    if start_block <= end_block do
      Logger.info("Block range for new batches discovery: #{start_block}..#{end_block}")

      NewBatches.discover(
        sequencer_inbox_address,
        start_block,
        end_block,
        new_batches_limit,
        messages_to_blocks_shift,
        l1_rpc_config,
        rollup_rpc_config
      )

      {:ok, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  def discover_historical_batches(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            rollup_rpc: rollup_rpc_config,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            l1_rollup_init_block: l1_rollup_init_block,
            new_batches_limit: new_batches_limit
          },
          data: %{historical_batches_end_block: end_block}
        } = _state
      ) do
    if end_block >= l1_rollup_init_block do
      start_block = max(l1_rollup_init_block, end_block - l1_rpc_config.logs_block_range + 1)

      Logger.info("Block range for historical batches discovery: #{start_block}..#{end_block}")

      NewBatches.discover_historical(
        sequencer_inbox_address,
        start_block,
        end_block,
        new_batches_limit,
        messages_to_blocks_shift,
        l1_rpc_config,
        rollup_rpc_config
      )

      {:ok, start_block}
    else
      {:ok, l1_rollup_init_block}
    end
  end

  def discover_new_rollup_confirmation(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address,
            rollup_rpc: rollup_rpc_config
          },
          data: %{new_confirmations_start_block: start_block}
        } = _state
      ) do
    # It makes sense to use "safe" here. Blocks are confirmed with delay in one week
    # (applicable for ArbitrumOne and Nova), so 10 mins delay is not significant
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        if(l1_rpc_config.finalized_confirmations, do: "safe", else: "latest"),
        l1_rpc_config.json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + l1_rpc_config.logs_block_range - 1, latest_block)

    if start_block <= end_block do
      Logger.info("Block range for new rollup confirmations discovery: #{start_block}..#{end_block}")

      retcode =
        NewConfirmations.discover(
          outbox_address,
          start_block,
          end_block,
          l1_rpc_config,
          rollup_rpc_config
        )

      {retcode, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  def discover_historical_rollup_confirmation(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address,
            rollup_rpc: rollup_rpc_config,
            l1_start_block: l1_start_block,
            l1_rollup_init_block: l1_rollup_init_block
          },
          data: %{
            historical_confirmations_end_block: expected_confirmation_end_block,
            historical_confirmations_start_block: expected_confirmation_start_block
          }
        } = _state
      ) do
    {interim_start_block, end_block} =
      case expected_confirmation_end_block do
        nil ->
          Db.l1_blocks_to_expect_rollup_blocks_confirmation(nil)

        _ ->
          {expected_confirmation_start_block, expected_confirmation_end_block}
      end

    with {:end_block_defined, false} <- {:end_block_defined, is_nil(end_block)},
         {:genesis_not_reached, true} <- {:genesis_not_reached, end_block >= l1_rollup_init_block} do
      start_block =
        case interim_start_block do
          nil ->
            max(l1_rollup_init_block, end_block - l1_rpc_config.logs_block_range + 1)

          value ->
            Enum.max([l1_rollup_init_block, value, end_block - l1_rpc_config.logs_block_range + 1])
        end

      Logger.info("Block range for historical rollup confirmations discovery: #{start_block}..#{end_block}")

      retcode =
        NewConfirmations.discover(
          outbox_address,
          start_block,
          end_block,
          l1_rpc_config,
          rollup_rpc_config
        )

      {retcode, {start_block, interim_start_block}}
    else
      {:end_block_defined, true} -> {:ok, {l1_start_block, nil}}
      {:genesis_not_reached, false} -> {:ok, {l1_rollup_init_block, nil}}
    end
  end

  defp discover_new_l1_messages_executions(
         %{
           config: %{
             l1_rpc: l1_rpc_config,
             l1_outbox_address: outbox_address
           },
           data: %{new_executions_start_block: start_block}
         } = _state
       ) do
    # Requesting the "latest" block instead of "safe" allows to catch executions
    # without latency.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        l1_rpc_config.json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + l1_rpc_config.logs_block_range - 1, latest_block)

    if start_block <= end_block do
      Logger.info("Block range for new l2-to-l1 messages executions discovery: #{start_block}..#{end_block}")

      NewL1Executions.discover(
        outbox_address,
        start_block,
        end_block,
        l1_rpc_config
      )

      {:ok, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  defp discover_historical_l1_messages_executions(
         %{
           config: %{
             l1_rpc: l1_rpc_config,
             l1_outbox_address: outbox_address,
             l1_rollup_init_block: l1_rollup_init_block
           },
           data: %{historical_executions_end_block: end_block}
         } = _state
       ) do
    if end_block >= l1_rollup_init_block do
      start_block = max(l1_rollup_init_block, end_block - l1_rpc_config.logs_block_range + 1)

      Logger.info("Block range for historical l2-to-l1 messages executions discovery: #{start_block}..#{end_block}")

      NewL1Executions.discover(
        outbox_address,
        start_block,
        end_block,
        l1_rpc_config
      )

      {:ok, start_block}
    else
      {:ok, l1_rollup_init_block}
    end
  end

  defp monitor_lifecycle_txs_finalization(state) do
    L1Finalization.monitor_lifecycle_txs(state.config.l1_rpc.json_rpc_named_arguments)
  end
end
