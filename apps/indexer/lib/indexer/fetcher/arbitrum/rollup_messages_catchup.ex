defmodule Indexer.Fetcher.Arbitrum.RollupMessagesCatchup do
  @moduledoc """
    Manages the catch-up process for historical rollup messages between Layer 1 (L1) and Layer 2 (L2) within the Arbitrum network.

    This module aims to discover historical messages that were not captured by the block
    fetcher or the catch-up block fetcher. This situation arises during the upgrade of an
    existing instance of BlockScout (BS) that already has indexed blocks but lacks
    a crosschain messages discovery mechanism. Therefore, it becomes necessary to traverse
    the already indexed blocks to extract crosschain messages contained within them.

    The fetcher's operation cycle consists of five phases, initiated by sending specific
    messages:
    - `:wait_for_new_block`: Waits for the block fetcher to index new blocks before
      proceeding with message discovery.
    - `:init_worker`: Sets up the initial parameters for the message discovery process,
      identifying the ending blocks for the search.
    - `:historical_msg_from_l2` and `:historical_msg_to_l2`: Manage the discovery and
      processing of messages sent from L2 to L1 and from L1 to L2, respectively.
    - `:plan_next_iteration`: Schedules the next iteration of the catch-up process.

    Workflow diagram of the fetcher state changes:

         wait_for_new_block
                 |
                 V
            init_worker
                 |
                 V
    |-> historical_msg_from_l2 -> historical_msg_to_l2 -> plan_next_iteration ->|
    |---------------------------------------------------------------------------|

    `historical_msg_from_l2` discovers L2-to-L1 messages by analyzing logs from already
    indexed rollup transactions. Logs representing the `L2ToL1Tx` event are utilized
    to construct messages. The current rollup state, including information about
    committed batches and confirmed blocks, is used to assign the appropriate status
    to the messages before importing them into the database.

    `historical_msg_to_l2` discovers L1-to-L2 messages by requesting rollup
    transactions through RPC. Transactions containing a `requestId` in their body are
    utilized to construct messages. These messages are marked as `:relayed`, indicating
    that they have been successfully received on L2 and are considered completed, and
    are then imported into the database. This approach is adopted because it parallels
    the action of re-indexing existing transactions to include Arbitrum-specific fields,
    which are absent in the currently indexed transactions. However, permanently adding
    these fields to the database model for the sake of historical message catch-up is
    impractical. Therefore, to avoid the extensive process of re-indexing and to
    minimize changes to the database schema, fetching the required data directly from
    an external node via RPC is preferred for historical message discovery.
  """

  use GenServer
  use Indexer.Fetcher

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [increase_duration: 2]

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Db
  alias Indexer.Fetcher.Arbitrum.Workers.HistoricalMessagesOnL2

  require Logger

  @wait_for_new_block_delay 15
  @release_cpu_delay 1

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
    Logger.metadata(fetcher: :arbitrum_bridge_l2_catchup)

    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    rollup_chunk_size = config_common[:rollup_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]
    messages_to_l2_blocks_depth = config_tracker[:messages_to_l2_blocks_depth]
    messages_from_l2_blocks_depth = config_tracker[:messages_to_l1_blocks_depth]

    Process.send(self(), :wait_for_new_block, [])

    {:ok,
     %{
       config: %{
         rollup_rpc: %{
           json_rpc_named_arguments: args[:json_rpc_named_arguments],
           chunk_size: rollup_chunk_size
         },
         json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
         recheck_interval: recheck_interval,
         messages_to_l2_blocks_depth: messages_to_l2_blocks_depth,
         messages_from_l2_blocks_depth: messages_from_l2_blocks_depth
       },
       data: %{}
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # Waits for the next new block to be picked up by the block fetcher before initiating
  # the worker for message discovery.
  #
  # This function checks if a new block has been indexed by the block fetcher since
  # the start of the historical messages fetcher. It queries the database to find
  # the closest block timestamped after this period. If a new block is found, it
  # initiates the worker process for message discovery by sending the `:init_worker`
  # message. If no new block is available, it reschedules itself to check again after
  # a specified delay.
  #
  # The number of the new block indexed by the block fetcher will be used by the worker
  # initializer to establish the end of the range where new messages should be discovered.
  #
  # ## Parameters
  # - `:wait_for_new_block`: The message that triggers the waiting process.
  # - `state`: The current state of the fetcher.
  #
  # ## Returns
  # - `{:noreply, new_state}` where the new indexed block number is stored, or retain
  #   the current state while awaiting new blocks.
  @impl GenServer
  def handle_info(:wait_for_new_block, %{data: _} = state) do
    {time_of_start, interim_data} =
      if is_nil(Map.get(state.data, :time_of_start)) do
        now = DateTime.utc_now()
        updated_data = Map.put(state.data, :time_of_start, now)
        {now, updated_data}
      else
        {state.data.time_of_start, state.data}
      end

    new_data =
      case Db.closest_block_after_timestamp(time_of_start) do
        {:ok, block} ->
          Process.send(self(), :init_worker, [])

          interim_data
          |> Map.put(:new_block, block)
          |> Map.delete(:time_of_start)

        {:error, _} ->
          log_warning("No progress of the block fetcher found")
          Process.send_after(self(), :wait_for_new_block, :timer.seconds(@wait_for_new_block_delay))
          interim_data
      end

    {:noreply, %{state | data: new_data}}
  end

  # Sets the initial parameters for discovering historical messages. This function
  # calculates the end blocks for both L1-to-L2 and L2-to-L1 message discovery
  # processes based on th earliest messages already indexed. If no messages are
  # available, the block number before the latest indexed block will be used.
  # These end blocks are used to initiate the discovery process in subsequent iterations.
  #
  # After identifying the initial values, the function immediately transitions to
  # the L2-to-L1 message discovery process by sending the `:historical_msg_from_l2`
  # message.
  #
  # ## Parameters
  # - `:init_worker`: The message that triggers the handler.
  # - `state`: The current state of the fetcher.
  #
  # ## Returns
  # - `{:noreply, new_state}` where the end blocks for both L1-to-L2 and L2-to-L1
  #   message discovery are established.
  @impl GenServer
  def handle_info(:init_worker, %{data: _} = state) do
    historical_msg_from_l2_end_block = Db.rollup_block_to_discover_missed_messages_from_l2(state.data.new_block - 1)
    historical_msg_to_l2_end_block = Db.rollup_block_to_discover_missed_messages_to_l2(state.data.new_block - 1)

    Process.send(self(), :historical_msg_from_l2, [])

    new_data =
      Map.merge(state.data, %{
        duration: 0,
        progressed: false,
        historical_msg_from_l2_end_block: historical_msg_from_l2_end_block,
        historical_msg_to_l2_end_block: historical_msg_to_l2_end_block
      })

    {:noreply, %{state | data: new_data}}
  end

  # Processes the next iteration of historical L2-to-L1 message discovery.
  #
  # This function uses the results from the previous iteration to set the end block
  # for the current message discovery iteration. It identifies the start block and
  # requests rollup logs within the specified range to explore `L2ToL1Tx` events.
  # Discovered events are used to compose messages to be stored in the database.
  # Before being stored in the database, each message is assigned the appropriate
  # status based on the current state of the rollup.
  #
  # After importing the messages, the function immediately switches to the process
  # of L1-to-L2 message discovery for the next range of blocks by sending
  # the `:historical_msg_to_l2` message.
  #
  # ## Parameters
  # - `:historical_msg_from_l2`: The message triggering the handler.
  # - `state`: The current state of the fetcher containing necessary data like
  #            the end block identified after the previous iteration of historical
  #            message discovery from L2.
  #
  # ## Returns
  # - `{:noreply, new_state}` where the end block for the next L2-to-L1 message
  #   discovery iteration is updated based on the results of the current iteration.
  @impl GenServer
  def handle_info(
        :historical_msg_from_l2,
        %{
          data: %{duration: _, historical_msg_from_l2_end_block: _, progressed: _}
        } = state
      ) do
    end_block = state.data.historical_msg_from_l2_end_block

    {handle_duration, {:ok, start_block}} =
      :timer.tc(&HistoricalMessagesOnL2.discover_historical_messages_from_l2/2, [end_block, state])

    Process.send(self(), :historical_msg_to_l2, [])

    progressed = state.data.progressed || (not is_nil(start_block) && start_block - 1 < end_block)

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        progressed: progressed,
        historical_msg_from_l2_end_block: if(is_nil(start_block), do: nil, else: start_block - 1)
      })

    {:noreply, %{state | data: new_data}}
  end

  # Processes the next iteration of historical L1-to-L2 message discovery.
  #
  # This function uses the results from the previous iteration to set the end block for
  # the current message discovery iteration. It identifies the start block and requests
  # rollup blocks within the specified range through RPC to explore transactions
  # containing a `requestId` in their body. This RPC request is necessary because the
  # `requestId` field is not present in the transaction model of already indexed
  # transactions in the database. The discovered transactions are then used to construct
  # messages, which are subsequently stored in the database. These imported messages are
  # marked as `:relayed`, signifying that they represent completed actions from L1 to L2.
  #
  # After importing the messages, the function immediately switches to the process
  # of choosing a delay prior to the next iteration of historical messages discovery
  # by sending the `:plan_next_iteration` message.
  #
  # ## Parameters
  # - `:historical_msg_to_l2`: The message triggering the handler.
  # - `state`: The current state of the fetcher containing necessary data, like the end
  #            block identified after the previous iteration of historical message discovery.
  #
  # ## Returns
  # - `{:noreply, new_state}` where the end block for the next L1-to-L2 message discovery
  #   iteration is updated based on the results of the current iteration.
  @impl GenServer
  def handle_info(
        :historical_msg_to_l2,
        %{
          data: %{duration: _, historical_msg_to_l2_end_block: _, progressed: _}
        } = state
      ) do
    end_block = state.data.historical_msg_to_l2_end_block

    {handle_duration, {:ok, start_block}} =
      :timer.tc(&HistoricalMessagesOnL2.discover_historical_messages_to_l2/2, [end_block, state])

    Process.send(self(), :plan_next_iteration, [])

    progressed = state.data.progressed || (not is_nil(start_block) && start_block - 1 < end_block)

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        progressed: progressed,
        historical_msg_to_l2_end_block: if(is_nil(start_block), do: nil, else: start_block - 1)
      })

    {:noreply, %{state | data: new_data}}
  end

  # Decides whether to stop or continue the fetcher based on the current state of message discovery.
  #
  # If both `historical_msg_from_l2_end_block` and `historical_msg_to_l2_end_block` are 0 or less,
  # indicating that there are no more historical messages to fetch, the task is stopped with a normal
  # termination.
  #
  # ## Parameters
  # - `:plan_next_iteration`: The message that triggers this function.
  # - `state`: The current state of the fetcher.
  #
  # ## Returns
  # - `{:stop, :normal, state}`: Ends the fetcher's operation cleanly.
  @impl GenServer
  def handle_info(
        :plan_next_iteration,
        %{
          data: %{
            historical_msg_from_l2_end_block: from_l2_end_block,
            historical_msg_to_l2_end_block: to_l2_end_block
          }
        } = state
      )
      when from_l2_end_block <= 0 and to_l2_end_block <= 0 do
    {:stop, :normal, state}
  end

  # Plans the next iteration for the historical messages discovery based on the state's `progressed` flag.
  #
  # If no progress was made (`progressed` is false), schedules the next check based
  # on the `recheck_interval`, adjusted by the time already spent. If progress was
  # made, it imposes a shorter delay to quickly check again, helping to reduce CPU
  # usage during idle periods.
  #
  # The chosen delay is used to schedule the next iteration of historical messages discovery
  # by sending `:historical_msg_from_l2`.
  #
  # ## Parameters
  # - `:plan_next_iteration`: The message that triggers this function.
  # - `state`: The current state of the fetcher containing both the fetcher configuration
  #            and data needed to determine the next steps.
  #
  # ## Returns
  # - `{:noreply, state}` where `state` contains the reset `duration` of the iteration and
  #   the flag if the messages discovery process `progressed`.
  @impl GenServer
  def handle_info(
        :plan_next_iteration,
        %{config: %{recheck_interval: _}, data: %{duration: _, progressed: _}} = state
      ) do
    next_timeout =
      if state.data.progressed do
        # For the case when all historical messages are not received yet
        # make a small delay to release CPU a bit
        :timer.seconds(@release_cpu_delay)
      else
        max(state.config.recheck_interval - div(state.data.duration, 1000), 0)
      end

    Process.send_after(self(), :historical_msg_from_l2, next_timeout)

    new_data =
      state.data
      |> Map.put(:duration, 0)
      |> Map.put(:progressed, false)

    {:noreply, %{state | data: new_data}}
  end
end
