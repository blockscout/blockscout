defmodule Indexer.Fetcher.ZkSync.BatchesStatusTracker do
  @moduledoc """
    Updates batches statuses and imports historical batches to the `zksync_transaction_batches` table.

    Repetitiveness is supported by sending the following statuses every `recheck_interval` seconds:
    - `:check_committed`: Discover batches committed to L1
    - `:check_proven`: Discover batches proven in L1
    - `:check_executed`: Discover batches executed on L1
    - `:recover_batches`: Recover missed batches found during the handling of the three previous messages
    - `:check_historical`: Check if the imported batches chain does not start with Batch #0

    The initial message is `:check_committed`. If it is discovered that updating batches
    in the `zksync_transaction_batches` table is not possible because some are missing,
    `:recover_batches` is sent. The next messages are `:check_proven` and `:check_executed`.
    Both could result in sending `:recover_batches` as well.

    The logic ensures that every handler emits the `:recover_batches` message to return to
    the previous "progressing" state. If `:recover_batches` is called during handling `:check_committed`,
    it will be sent again after finishing batch recovery. Similar logic applies to `:check_proven` and
    `:check_executed`.

    The last message in the loop is `:check_historical`.

    |---------------------------------------------------------------------------|
    |-> check_committed -> check_proven -> check_executed -> check_historical ->|
            |    ^           |    ^            |    ^
            v    |           v    |            v    |
        recover_batches   recover_batches  recover_batches

    If a batch status change is discovered during handling of `check_committed`, `check_proven`,
    or `check_executed` messages, the corresponding L1 transactions are imported and associated
    with the batches. Rollup transactions and blocks are not re-associated since it is assumed
    to be done by `Indexer.Fetcher.ZkSync.TransactionBatch` or during handling of
    the `recover_batches` message.

    The `recover_batches` handler downloads batch information from RPC and sets its actual L1 state
    by linking with L1 transactions.

    The `check_historical` message initiates the check if the tail of the batch chain is Batch 0.
    If the tail is missing, batches are downloaded from RPC in chunks of `batches_max_range` in every
    iteration. The batches are imported together with associated L1 transactions.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  # alias Explorer.Chain.Events.Publisher
  # TODO: publish event when new committed batches appear

  alias Indexer.Fetcher.ZkSync.Discovery.Workers
  alias Indexer.Fetcher.ZkSync.StatusTracking.{Committed, Executed, Proven}

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
    Logger.metadata(fetcher: :zksync_batches_tracker)

    config_tracker = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.BatchesStatusTracker]
    l1_rpc = config_tracker[:zksync_l1_rpc]
    recheck_interval = config_tracker[:recheck_interval]
    config_fetcher = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.TransactionBatch]
    chunk_size = config_fetcher[:chunk_size]
    batches_max_range = config_fetcher[:batches_max_range]

    Process.send(self(), :check_committed, [])

    {:ok,
     %{
       config: %{
         json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
         json_l1_rpc_named_arguments: [
           transport: EthereumJSONRPC.HTTP,
           transport_options: [
             http: EthereumJSONRPC.HTTP.Tesla,
             urls: [l1_rpc],
             http_options: [
               recv_timeout: :timer.minutes(10),
               timeout: :timer.minutes(10),
               pool: :ethereum_jsonrpc
             ]
           ]
         ],
         recheck_interval: recheck_interval,
         chunk_size: chunk_size,
         batches_max_range: batches_max_range
       },
       data: %{}
     }}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # Handles the `:check_historical` message to download historical batches from RPC if necessary and
  # import them to the `zksync_transaction_batches` table. The batches are imported together with L1
  # transactions associations, rollup blocks and transactions.
  # Since it is the final handler in the loop, it schedules sending the `:check_committed` message
  # to initiate the next iteration. The sending of the message is delayed, taking into account
  # the time remaining after the previous handlers' execution.
  #
  # ## Parameters
  # - `:check_historical`: the message triggering the handler
  # - `state`: current state of the fetcher containing both the fetcher configuration
  #            and data re-used by different handlers.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` contains `data` empty
  @impl GenServer
  def handle_info(:check_historical, state)
      when is_map(state) and is_map_key(state, :config) and is_map_key(state, :data) and
             is_map_key(state.config, :recheck_interval) and is_map_key(state.config, :batches_max_range) and
             is_map_key(state.config, :json_l2_rpc_named_arguments) and
             is_map_key(state.config, :chunk_size) do
    {handle_duration, _} =
      :timer.tc(&Workers.batches_catchup/1, [
        %{
          batches_max_range: state.config.batches_max_range,
          chunk_size: state.config.chunk_size,
          json_rpc_named_arguments: state.config.json_l2_rpc_named_arguments
        }
      ])

    Process.send_after(
      self(),
      :check_committed,
      max(:timer.seconds(state.config.recheck_interval) - div(update_duration(state.data, handle_duration), 1000), 0)
    )

    {:noreply, %{state | data: %{}}}
  end

  # Handles the `:recover_batches` message to download a set of batches from RPC and imports them
  # to the `zksync_transaction_batches` table. It is expected that the message is sent from handlers updating
  # batches statuses when they discover the absence of batches in the `zksync_transaction_batches` table.
  # The batches are imported together with L1 transactions associations, rollup blocks, and transactions.
  #
  # ## Parameters
  # - `:recover_batches`: the message triggering the handler
  # - `state`: current state of the fetcher containing both the fetcher configuration
  #             and data related to the batches recovery:
  #             - `state.data.batches`: list of the batches to recover
  #             - `state.data.switched_from`: the message to send after the batch recovery
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` contains updated `duration` of the iteration
  @impl GenServer
  def handle_info(:recover_batches, state)
      when is_map(state) and is_map_key(state, :config) and is_map_key(state, :data) and
             is_map_key(state.config, :json_l2_rpc_named_arguments) and is_map_key(state.config, :chunk_size) and
             is_map_key(state.data, :batches) and is_map_key(state.data, :switched_from) do
    {handle_duration, _} =
      :timer.tc(
        &Workers.get_full_batches_info_and_import/2,
        [
          state.data.batches,
          %{
            chunk_size: state.config.chunk_size,
            json_rpc_named_arguments: state.config.json_l2_rpc_named_arguments
          }
        ]
      )

    Process.send(self(), state.data.switched_from, [])

    {:noreply, %{state | data: %{duration: update_duration(state.data, handle_duration)}}}
  end

  # Handles `:check_committed`, `:check_proven`, and `:check_executed` messages to update the
  # statuses of batches by associating L1 transactions with them. For different messages, it invokes
  # different underlying functions due to different natures of discovering batches with changed status.
  # Another reason why statuses are being tracked differently is the different pace of status changes:
  # a batch is committed in a few minutes after sealing, proven in a few hours, and executed once in a day.
  # Depending on the value returned from the underlying function, either a message (`:check_proven`,
  # `:check_executed`, or `:check_historical`) to switch to the next status checker is sent, or a list
  # of batches to recover is provided together with `:recover_batches`.
  #
  # ## Parameters
  # - `input`: one of `:check_committed`, `:check_proven`, and `:check_executed`
  # - `state`: the current state of the fetcher containing both the fetcher configuration
  #            and data reused by different handlers.
  #
  # ## Returns
  # - `{:noreply, new_state}` where `new_state` contains the updated `duration` of the iteration,
  #   could also contain the list of batches to recover and the message to return back to
  #   the corresponding status update checker.
  @impl GenServer
  def handle_info(input, state)
      when input in [:check_committed, :check_proven, :check_executed] do
    {output, func} =
      case input do
        :check_committed -> {:check_proven, &Committed.look_for_batches_and_update/1}
        :check_proven -> {:check_executed, &Proven.look_for_batches_and_update/1}
        :check_executed -> {:check_historical, &Executed.look_for_batches_and_update/1}
      end

    {handle_duration, result} = :timer.tc(func, [state.config])

    {switch_to, state_data} =
      case result do
        :ok ->
          {output, %{duration: update_duration(state.data, handle_duration)}}

        {:recovery_required, batches} ->
          {:recover_batches,
           %{
             switched_from: input,
             batches: batches,
             duration: update_duration(state.data, handle_duration)
           }}
      end

    Process.send(self(), switch_to, [])
    {:noreply, %{state | data: state_data}}
  end

  defp update_duration(data, cur_duration) do
    if Map.has_key?(data, :duration) do
      data.duration + cur_duration
    else
      cur_duration
    end
  end
end
