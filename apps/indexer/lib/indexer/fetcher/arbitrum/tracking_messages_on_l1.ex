defmodule Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1 do
  @moduledoc """
    Manages the tracking and processing of new and historical cross-chain messages initiated on L1 for an Arbitrum rollup.

    This module is responsible for continuously monitoring and importing new messages
    initiated from Layer 1 (L1) to Arbitrum's Layer 2 (L2), as well as discovering
    and processing historical messages that were sent previously but have not yet
    been processed.

    The fetcher's operation is divided into 3 phases, each initiated by sending
    specific messages:
    - `:init_worker`: Initializes the worker with the required configuration for message
      tracking.
    - `:check_new_msgs_to_rollup`: Processes new L1-to-L2 messages appearing on L1 as
      the blockchain progresses.
    - `:check_historical_msgs_to_rollup`: Retrieves historical L1-to-L2 messages that
      were missed if the message synchronization process did not start from the
      Arbitrum rollup's inception.

    While the `:init_worker` message is sent only once during the fetcher startup,
    the subsequent sending of `:check_new_msgs_to_rollup` and
    `:check_historical_msgs_to_rollup` forms the operation cycle of the fetcher.

    Discovery of L1-to-L2 messages is executed by requesting logs on L1 that correspond
    to the `MessageDelivered` event emitted by the Arbitrum bridge contract.
    Cross-chain messages are composed of information from the logs' data as well as from
    the corresponding transaction details. To get the transaction details, RPC calls
    `eth_getTransactionByHash` are made in chunks.
  """

  use GenServer
  use Indexer.Fetcher

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [increase_duration: 2]

  alias EthereumJSONRPC.Arbitrum, as: ArbitrumRpc

  alias Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
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
    Logger.metadata(fetcher: :arbitrum_bridge_l1)

    config_common = Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum]
    l1_rpc = config_common[:l1_rpc]
    l1_rpc_block_range = config_common[:l1_rpc_block_range]
    l1_rollup_address = config_common[:l1_rollup_address]
    l1_rollup_init_block = config_common[:l1_rollup_init_block]
    l1_start_block = config_common[:l1_start_block]
    l1_rpc_chunk_size = config_common[:l1_rpc_chunk_size]

    config_tracker = Application.get_all_env(:indexer)[__MODULE__]
    recheck_interval = config_tracker[:recheck_interval]

    Process.send(self(), :init_worker, [])

    {:ok,
     %{
       config: %{
         json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
         json_l1_rpc_named_arguments: IndexerHelper.json_rpc_named_arguments(l1_rpc),
         recheck_interval: recheck_interval,
         l1_rpc_chunk_size: l1_rpc_chunk_size,
         l1_rpc_block_range: l1_rpc_block_range,
         l1_rollup_address: l1_rollup_address,
         l1_start_block: l1_start_block,
         l1_rollup_init_block: l1_rollup_init_block
       },
       data: %{}
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # Initializes the worker for discovering new and historical L1-to-L2 messages.
  #
  # This function prepares the initial parameters for the message discovery process.
  # It fetches the Arbitrum bridge address and determines the starting block for
  # new message discovery. If the starting block is not configured (set to a default
  # value), the latest block number from L1 is used as the start. It also calculates
  # the end block for historical message discovery.
  #
  # After setting these parameters, it immediately transitions to discovering new
  # messages by sending the `:check_new_msgs_to_rollup` message.
  #
  # ## Parameters
  # - `:init_worker`: The message triggering the initialization.
  # - `state`: The current state of the process, containing configuration for data
  #            initialization and further message discovery.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` is updated with the bridge address,
  #   determined start block for new messages, and calculated end block for
  #   historical messages.
  @impl GenServer
  def handle_info(
        :init_worker,
        %{config: %{l1_rollup_address: _, json_l1_rpc_named_arguments: _, l1_start_block: _}, data: _} = state
      ) do
    %{bridge: bridge_address} =
      ArbitrumRpc.get_contracts_for_rollup(
        state.config.l1_rollup_address,
        :bridge,
        state.config.json_l1_rpc_named_arguments
      )

    l1_start_block = Rpc.get_l1_start_block(state.config.l1_start_block, state.config.json_l1_rpc_named_arguments)
    new_msg_to_l2_start_block = DbMessages.l1_block_to_discover_latest_message_to_l2(l1_start_block)
    historical_msg_to_l2_end_block = DbMessages.l1_block_to_discover_earliest_message_to_l2(l1_start_block - 1)

    Process.send(self(), :check_new_msgs_to_rollup, [])

    new_state =
      state
      |> Map.put(
        :config,
        Map.merge(state.config, %{
          l1_start_block: l1_start_block,
          l1_bridge_address: bridge_address
        })
      )
      |> Map.put(
        :data,
        Map.merge(state.data, %{
          new_msg_to_l2_start_block: new_msg_to_l2_start_block,
          historical_msg_to_l2_end_block: historical_msg_to_l2_end_block
        })
      )

    {:noreply, new_state}
  end

  # Initiates the process to discover and handle new L1-to-L2 messages initiated from L1.
  #
  # This function discovers new messages from L1 to L2 by retrieving logs for the
  # calculated L1 block range. Discovered events are used to compose messages, which
  # are then stored in the database.
  #
  # After processing, the function immediately transitions to discovering historical
  # messages by sending the `:check_historical_msgs_to_rollup` message.
  #
  # ## Parameters
  # - `:check_new_msgs_to_rollup`: The message that triggers the handler.
  # - `state`: The current state of the fetcher, containing configuration and data
  #            needed for message discovery.
  #
  # ## Returns
  # - `{:noreply, new_state}` where the starting block for the next new L1-to-L2
  #   message discovery iteration is updated based on the results of the current
  #   iteration.
  @impl GenServer
  def handle_info(:check_new_msgs_to_rollup, %{data: _} = state) do
    {handle_duration, {:ok, end_block}} =
      :timer.tc(&NewMessagesToL2.discover_new_messages_to_l2/1, [
        state
      ])

    Process.send(self(), :check_historical_msgs_to_rollup, [])

    new_data =
      Map.merge(state.data, %{
        duration: increase_duration(state.data, handle_duration),
        new_msg_to_l2_start_block: end_block + 1
      })

    {:noreply, %{state | data: new_data}}
  end

  # Initiates the process to discover and handle historical L1-to-L2 messages initiated from L1.
  #
  # This function discovers historical messages by retrieving logs for a calculated L1 block range.
  # The discovered events are then used to compose messages to be stored in the database.
  #
  # After processing, as it is the final handler in the loop, it schedules the
  # `:check_new_msgs_to_rollup` message to initiate the next iteration. The scheduling of this
  # message is delayed, taking into account the time spent on the previous handler's execution.
  #
  # ## Parameters
  # - `:check_historical_msgs_to_rollup`: The message that triggers the handler.
  # - `state`: The current state of the fetcher, containing configuration and data needed for
  #            message discovery.
  #
  # ## Returns
  # - `{:noreply, new_state}` where the end block for the next L1-to-L2 message discovery
  #   iteration is updated based on the results of the current iteration.
  @impl GenServer
  def handle_info(:check_historical_msgs_to_rollup, %{config: %{recheck_interval: _}, data: _} = state) do
    {handle_duration, {:ok, start_block}} =
      :timer.tc(&NewMessagesToL2.discover_historical_messages_to_l2/1, [
        state
      ])

    next_timeout = max(state.config.recheck_interval - div(increase_duration(state.data, handle_duration), 1000), 0)

    Process.send_after(self(), :check_new_msgs_to_rollup, next_timeout)

    new_data =
      Map.merge(state.data, %{
        duration: 0,
        historical_msg_to_l2_end_block: start_block - 1
      })

    {:noreply, %{state | data: new_data}}
  end
end
