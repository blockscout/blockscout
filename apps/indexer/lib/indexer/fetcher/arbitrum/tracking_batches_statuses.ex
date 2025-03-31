defmodule Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses do
  @moduledoc """
    Manages the tracking and updating of the statuses of rollup batches,
    confirmations, and cross-chain message executions for an Arbitrum rollup.

    This module orchestrates the workflow for discovering new and historical
    batches of rollup transactions, confirmations of rollup blocks, and executions
    of L2-to-L1 messages. It ensures the accurate tracking and updating of the
    rollup process stages.

    The fetcher's operation cycle begins with the `:init_worker` message, which
    establishes the initial state with the necessary configuration.

    The process then progresses through a sequence of steps, each triggered by
    specific messages:
    - `:check_new_batches`: Discovers new batches of rollup transactions and
      updates their statuses.
    - `:check_new_confirmations`: Identifies new confirmations of rollup blocks to
      update their statuses.
    - `:check_new_executions`: Finds new executions of L2-to-L1 messages to update
      their statuses.
    - `:check_historical_batches`: Processes historical batches of rollup
      transactions.
    - `:check_missing_batches`: Inspects for missing batches of rollup transactions.
    - `:check_historical_confirmations`: Handles historical confirmations of
      rollup blocks.
    - `:check_historical_executions`: Manages historical executions of L2-to-L1
      messages.
    - `:check_lifecycle_transactions_finalization`: Finalizes the status of lifecycle
      transactions, confirming the blocks and messages involved.

    Discovery of rollup transaction batches is executed by requesting logs on L1
    that correspond to the `SequencerBatchDelivered` event emitted by the Arbitrum
    `SequencerInbox` contract.

    Discovery of rollup block confirmations is executed by requesting logs on L1
    that correspond to the `SendRootUpdated` event emitted by the Arbitrum `Outbox`
    contract.

    Discovery of the L2-to-L1 message executions occurs by requesting logs on L1
    that correspond to the `OutBoxTransactionExecuted` event emitted by the
    Arbitrum `Outbox` contract.

    When processing batches or confirmations, the L2-to-L1 messages included in
    the corresponding rollup blocks are updated to reflect their status changes.
  """

  use GenServer
  use Indexer.Fetcher

  alias Indexer.Fetcher.Arbitrum.Workers.Batches.Tasks, as: BatchesDiscoveryTasks
  alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Tasks, as: ConfirmationsDiscoveryTasks
  alias Indexer.Fetcher.Arbitrum.Workers.{L1Finalization, NewL1Executions}

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [increase_duration: 2]

  alias EthereumJSONRPC.Arbitrum, as: ArbitrumRpc
  alias EthereumJSONRPC.Utility.RangesHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

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
    l1_start_block = config_common[:l1_start_block]
    l1_rpc_chunk_size = config_common[:l1_rpc_chunk_size]
    rollup_chunk_size = config_common[:rollup_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]
    messages_to_blocks_shift = config_tracker[:messages_to_blocks_shift]
    track_l1_transaction_finalization = config_tracker[:track_l1_transaction_finalization]
    finalized_confirmations = config_tracker[:finalized_confirmations]
    confirmation_batches_depth = config_tracker[:confirmation_batches_depth]
    new_batches_limit = config_tracker[:new_batches_limit]
    missing_batches_range = config_tracker[:missing_batches_range]
    node_interface_address = config_tracker[:node_interface_contract]

    indexer_first_block =
      RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :block_ranges))

    Process.send(self(), :init_worker, [])

    {:ok,
     %{
       config: %{
         l1_rpc: %{
           json_rpc_named_arguments: IndexerHelper.json_rpc_named_arguments(l1_rpc),
           logs_block_range: l1_rpc_block_range,
           chunk_size: l1_rpc_chunk_size,
           track_finalization: track_l1_transaction_finalization,
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
         missing_batches_range: missing_batches_range,
         messages_to_blocks_shift: messages_to_blocks_shift,
         confirmation_batches_depth: confirmation_batches_depth,
         node_interface_address: node_interface_address,
         rollup_first_block: indexer_first_block
       },
       data: %{}
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # Initializes the worker for discovering batches of rollup transactions, confirmations of rollup blocks, and executions of L2-to-L1 messages.
  #
  # This function sets up the initial state for the fetcher, identifying the
  # starting blocks for new and historical discoveries of batches, confirmations,
  # and executions. It also retrieves addresses for the Arbitrum Outbox and
  # SequencerInbox contracts.
  #
  # After initializing these parameters, it immediately sends `:check_new_batches`
  # to commence the fetcher loop.
  #
  # ## Parameters
  # - `:init_worker`: The message triggering the initialization.
  # - `state`: The current state of the process, containing initial configuration
  #            data.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is updated with Arbitrum contract
  #   addresses and starting blocks for new and historical discoveries.
  @impl GenServer
  def handle_info(
        :init_worker,
        %{
          config: %{
            l1_rpc: %{json_rpc_named_arguments: json_l1_rpc_named_arguments},
            l1_rollup_address: l1_rollup_address
          }
        } = state
      ) do
    %{outbox: outbox_address, sequencer_inbox: sequencer_inbox_address} =
      ArbitrumRpc.get_contracts_for_rollup(
        l1_rollup_address,
        :inbox_outbox,
        json_l1_rpc_named_arguments
      )

    l1_start_block = Rpc.get_l1_start_block(state.config.l1_start_block, json_l1_rpc_named_arguments)

    new_batches_start_block = DbSettlement.l1_block_to_discover_latest_committed_batch(l1_start_block)
    historical_batches_end_block = DbSettlement.l1_block_to_discover_earliest_committed_batch(l1_start_block - 1)

    new_confirmations_start_block = DbSettlement.l1_block_of_latest_confirmed_block(l1_start_block)

    new_executions_start_block = DbMessages.l1_block_to_discover_latest_execution(l1_start_block)
    historical_executions_end_block = DbMessages.l1_block_to_discover_earliest_execution(l1_start_block - 1)

    {lowest_batch, missing_batches_end_batch} = DbSettlement.get_min_max_batch_numbers()

    Process.send(self(), :check_new_batches, [])

    new_state =
      state
      |> Map.put(
        :config,
        Map.merge(state.config, %{
          l1_start_block: l1_start_block,
          l1_outbox_address: outbox_address,
          l1_sequencer_inbox_address: sequencer_inbox_address,
          lowest_batch: lowest_batch
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
          historical_executions_end_block: historical_executions_end_block,
          missing_batches_end_batch: missing_batches_end_batch
        })
      )

    {:noreply, new_state}
  end

  # Initiates the process of discovering and handling new batches of rollup transactions.
  #
  # This function fetches logs within the calculated L1 block range to identify new
  # batches of rollup transactions. The discovered batches and their corresponding
  # rollup blocks and transactions are processed and linked. The L2-to-L1 messages
  # included in these rollup blocks are also updated to reflect their commitment.
  #
  # After processing, it immediately transitions to checking new confirmations of
  # rollup blocks by sending the `:check_new_confirmations` message.
  #
  # ## Parameters
  # - `:check_new_batches`: The message that triggers the function.
  # - `state`: The current state of the fetcher, containing configuration and data
  #            needed for the discovery of new batches.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is updated with the new start block for
  #   the next iteration of new batch discovery.
  @impl GenServer
  def handle_info(:check_new_batches, state) do
    {handle_duration, {:ok, end_block}} = :timer.tc(&BatchesDiscoveryTasks.check_new/1, [state])

    Process.send(self(), :check_new_confirmations, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        new_batches_start_block: end_block + 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # Initiates the discovery and processing of new confirmations for rollup blocks.
  #
  # This function fetches logs within the calculated L1 block range to identify
  # new confirmations for rollup blocks. The discovered confirmations are
  # processed to update the status of rollup blocks and L2-to-L1 messages
  # accordingly.
  #
  # After processing, it immediately transitions to discovering new executions
  # of L2-to-L1 messages by sending the `:check_new_executions` message.
  #
  # ## Parameters
  # - `:check_new_confirmations`: The message that triggers the function.
  # - `state`: The current state of the fetcher, containing configuration and
  #            data needed for the discovery of new rollup block confirmations.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is updated with the new start
  #   block for the next iteration of new confirmation discovery.
  @impl GenServer
  def handle_info(:check_new_confirmations, state) do
    {handle_duration, {_, new_state}} =
      :timer.tc(&ConfirmationsDiscoveryTasks.plan/2, [&ConfirmationsDiscoveryTasks.check_new/1, state])

    Process.send(self(), :check_new_executions, [])

    new_data = Map.put(new_state.data, :duration, increase_duration(state.data, handle_duration))

    {:noreply, %{state | data: new_data}}
  end

  # Initiates the process of discovering and handling new executions for L2-to-L1 messages.
  #
  # This function identifies new executions of L2-to-L1 messages by fetching logs
  # for the calculated L1 block range. It updates the status of these messages and
  # links them with the corresponding lifecycle transactions.
  #
  # After processing, it immediately transitions to checking historical batches of
  # rollup transaction by sending the `:check_historical_batches` message.
  #
  # ## Parameters
  # - `:check_new_executions`: The message that triggers the function.
  # - `state`: The current state of the fetcher, containing configuration and data
  #            needed for the discovery of new message executions.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is updated with the new start
  #   block for the next iteration of new message executions discovery.
  @impl GenServer
  def handle_info(:check_new_executions, state) do
    {handle_duration, {:ok, end_block}} = :timer.tc(&NewL1Executions.discover_new_l1_messages_executions/1, [state])

    Process.send(self(), :check_historical_batches, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        new_executions_start_block: end_block + 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # Initiates the process of discovering and handling historical batches of rollup transactions.
  #
  # This function fetches logs within the calculated L1 block range to identify the
  # historical batches of rollup transactions. After discovery the linkage between
  # batches and the corresponding rollup blocks and transactions are build. The
  # status of the L2-to-L1 messages included in the  corresponding rollup blocks is
  # also updated.
  #
  # After processing, it immediately transitions to inspecting for missing batches
  # of rollup blocks by sending the `:check_missing_batches`
  # message.
  #
  # ## Parameters
  # - `:check_historical_batches`: The message that triggers the function.
  # - `state`: The current state of the fetcher, containing configuration and data
  #            needed for the discovery of historical batches.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is updated with the new end block
  #   for the next iteration of historical batch discovery.
  @impl GenServer
  def handle_info(:check_historical_batches, state) do
    {handle_duration, {:ok, start_block, new_state}} = :timer.tc(&BatchesDiscoveryTasks.check_historical/1, [state])

    Process.send(self(), :check_missing_batches, [])

    new_data =
      Map.merge(new_state.data, %{
        duration: increase_duration(state.data, handle_duration),
        historical_batches_end_block: start_block - 1
      })

    {:noreply, %{new_state | data: new_data}}
  end

  # Initiates the process of inspecting for missing batches of rollup transactions.
  #
  # This function inspects the database for missing batches within the calculated
  # batch range. If a missing batch is identified, the L1 block range to look up
  # for the transaction that committed the batch is built based on the neighboring
  # batches. Then logs within the block range are fetched to get the batch data.
  # After discovery, the linkage between batches and the corresponding rollup
  # blocks and transactions is built. The status of the L2-to-L1 messages included
  # in the corresponding rollup blocks is also updated.
  #
  # After processing, it immediately transitions to checking historical
  # confirmations of rollup blocks by sending the `:check_historical_confirmations`
  # message.
  #
  # ## Parameters
  # - `:check_missing_batches`: The message that triggers the function.
  # - `state`: The current state of the fetcher, containing configuration and data
  #            needed for inspection of the missed batches.
  #
  # ## Returns
  # - `{:noreply, new_state}`: Where `new_state` is updated with the new end batch
  #   for the next iteration of missing batches inspection.
  @impl GenServer
  def handle_info(:check_missing_batches, state) do
    # At the moment of the very first fetcher running, no batches were found yet
    new_data =
      if is_nil(state.config.lowest_batch) do
        state.data
      else
        {handle_duration, {:ok, start_batch, new_state}} =
          :timer.tc(&BatchesDiscoveryTasks.inspect_for_missing/1, [state])

        Map.merge(new_state.data, %{
          duration: increase_duration(state.data, handle_duration),
          missing_batches_end_batch: start_batch - 1
        })
      end

    Process.send(self(), :check_historical_confirmations, [])

    {:noreply, %{state | data: new_data}}
  end

  # Initiates the process of discovering and handling historical confirmations of rollup blocks.
  #
  # This function fetches logs within the calculated range to identify the
  # historical confirmations of rollup blocks. The discovered confirmations are
  # processed to update the status of rollup blocks and L2-to-L1 messages
  # accordingly.
  #
  # After processing, it immediately transitions to checking historical executions
  # of L2-to-L1 messages by sending the `:check_historical_executions` message.
  #
  # ## Parameters
  # - `:check_historical_confirmations`: The message that triggers the function.
  # - `state`: The current state of the fetcher, containing configuration and data
  #            needed for the discovery of historical confirmations.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is updated with the new start and
  #   end blocks for the next iteration of historical confirmations discovery.
  @impl GenServer
  def handle_info(:check_historical_confirmations, state) do
    {handle_duration, {_, new_state}} =
      :timer.tc(&ConfirmationsDiscoveryTasks.plan/2, [&ConfirmationsDiscoveryTasks.check_unprocessed/1, state])

    Process.send(self(), :check_historical_executions, [])

    new_data = Map.put(new_state.data, :duration, increase_duration(state.data, handle_duration))

    {:noreply, %{state | data: new_data}}
  end

  # Initiates the discovery and handling of historical L2-to-L1 message executions.
  #
  # This function discovers historical executions of L2-to-L1 messages by retrieving
  # logs within a specified L1 block range. It updates their status accordingly and
  # builds the link between the messages and the lifecycle transactions where they
  # are executed.
  #
  # After processing, it immediately transitions to finalizing lifecycle transactions
  # by sending the `:check_lifecycle_transactions_finalization` message.
  #
  # ## Parameters
  # - `:check_historical_executions`: The message that triggers the function.
  # - `state`: The current state of the fetcher, containing configuration and data
  #            needed for the discovery of historical executions.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is updated with the new end block for
  #   the next iteration of historical executions.
  @impl GenServer
  def handle_info(:check_historical_executions, state) do
    {handle_duration, {:ok, start_block, new_state}} =
      :timer.tc(&NewL1Executions.discover_historical_l1_messages_executions/1, [state])

    Process.send(self(), :check_lifecycle_transactions_finalization, [])

    new_data =
      Map.merge(new_state.data, %{
        duration: increase_duration(state.data, handle_duration),
        historical_executions_end_block: start_block - 1
      })

    {:noreply, %{new_state | data: new_data}}
  end

  # Handles the periodic finalization check of lifecycle transactions.
  #
  # This function updates the finalization status of lifecycle transactions based on
  # the current state of the L1 blockchain. It discovers all transactions that are not
  # yet finalized up to the `safe` L1 block and changes their status to `:finalized`.
  #
  # After processing, as the final handler in the loop, it schedules the
  # `:check_new_batches` message to initiate the next iteration. The scheduling of this
  # message is delayed to account for the time spent on the previous handlers' execution.
  #
  # ## Parameters
  # - `:check_lifecycle_transactions_finalization`: The message that triggers the function.
  # - `state`: The current state of the fetcher, containing the configuration needed for
  #            the lifecycle transactions status update.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is the updated state with the reset duration.
  @impl GenServer
  def handle_info(:check_lifecycle_transactions_finalization, state) do
    {handle_duration, _} =
      if state.config.l1_rpc.track_finalization do
        :timer.tc(&L1Finalization.monitor_lifecycle_transactions/1, [state])
      else
        {0, nil}
      end

    next_timeout = max(state.config.recheck_interval - div(increase_duration(state.data, handle_duration), 1000), 0)

    Process.send_after(self(), :check_new_batches, next_timeout)

    new_data =
      Map.merge(state.data, %{
        duration: 0
      })

    {:noreply, %{state | data: new_data}}
  end
end
