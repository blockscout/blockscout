defmodule Indexer.Fetcher.Arbitrum.L2ToL1StatusReconciler do
  @moduledoc """
  Manages the status reconciliation of L2-to-L1 messages in the Arbitrum protocol.

  This module implements a buffered task system to handle the status updates of L2-to-L1
  messages based on the current state of the rollup chain. It processes messages in batches,
  updating their status according to the highest committed and confirmed block numbers:
  - Messages originating from a rollup block that is less than or equal to the highest
    committed block are marked as ':sent'.
  - Messages originating from a rollup block that is less than or equal to the highest
    confirmed block are marked as ':confirmed'.

  Messages in the queue are tracked with their processing state to prevent redundant processing:
  - New messages are represented as {message_id, block_number}
  - Messages already marked as sent are represented as {message_id, block_number, :sent}

  The only messages in the queue are those in the `:initiated` or `:sent` states.
  If a message needs to be updated to the `:confirmed` state, it is returned to the queue
  with the `:sent` marker to prevent redundant processing in subsequent iterations.

  At startup, the database is queried for all messages in the `:initiated` or
  `:sent` states. These messages are added to the queue. Messages are also added
  to the queue when either the block fetcher or the messages catchup process
  (`RollupMessagesCatchup`) discovers them.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Ecto.Query
  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_debug: 1, log_info: 1]

  alias Ecto.Multi

  alias Explorer.Chain.Arbitrum.Message
  alias Explorer.Chain.Cache.ArbitrumSettlement
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.L2ToL1StatusReconciler.Supervisor, as: L2ToL1StatusReconcilerSupervisor
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages

  require Logger

  @behaviour BufferedTask

  @typep ops_state :: %{
           :last_log_time => DateTime.t() | nil,
           :confirmed_counter => non_neg_integer(),
           :sent_counter => non_neg_integer(),
           :statistics_timer => reference() | nil,
           :max_batch_size => non_neg_integer(),
           optional(any()) => any()
         }

  @typep new_message :: {non_neg_integer(), non_neg_integer()}
  @typep message_marked_as_sent :: {non_neg_integer(), non_neg_integer(), :sent}
  @typep message_in_queue :: new_message() | message_marked_as_sent()

  @default_max_concurrency 1
  @max_flush_interval :timer.minutes(10)
  @log_interval :timer.minutes(1)

  def child_spec([init_options, gen_server_options]) do
    max_batch_size = Application.get_env(:indexer, __MODULE__)[:max_batch_size]

    recheck_interval =
      Application.get_env(:indexer, Indexer.Fetcher.Arbitrum.TrackingBatchesStatuses)[:recheck_interval]

    buffered_task_init_options =
      max_batch_size
      |> defaults(recheck_interval)
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, initial_state(max_batch_size))

    Supervisor.child_spec({BufferedTask, [{__MODULE__, buffered_task_init_options}, gen_server_options]},
      id: __MODULE__
    )
  end

  defp defaults(max_batch_size, recheck_interval) do
    flush_interval = min(recheck_interval, @max_flush_interval)

    [
      flush_interval: flush_interval,
      max_concurrency: @default_max_concurrency,
      max_batch_size: max_batch_size,
      poll: false,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :l2_to_l1_status_reconciler]
    ]
  end

  defp initial_state(max_batch_size) do
    %{
      last_log_time: nil,
      confirmed_counter: 0,
      sent_counter: 0,
      statistics_timer: nil,
      max_batch_size: max_batch_size
    }
  end

  @impl BufferedTask
  # Initializes the queue with unconfirmed L2-to-L1 messages from the database.
  @spec init({0, []}, function(), any()) :: {non_neg_integer(), [new_message()]}
  def init(initial, reducer, _) do
    DbMessages.stream_unconfirmed_messages_from_l2(initial, reducer)
  end

  @impl BufferedTask
  # Processes a batch of L2-to-L1 messages, updating their status based on the current
  # state of the rollup chain.
  #
  # The function first retrieves the current highest committed and confirmed block numbers
  # from the rollup chain. It then categorizes messages into three groups based on their
  # originating block number:
  # 1. Messages to confirm: originating block <= highest_confirmed_block
  # 2. Messages to commit: originating block <= highest_committed_block
  #
  # The function uses Ecto.Multi to perform all database updates in a single transaction.
  #
  # All messages except those which are marked as `:confirmed` are added back to the
  # queue to be processed in future iterations.
  #
  # ## Parameters
  #   * `messages_with_blocks` - List of tuples {message_id, originating_block_number}
  #   * `state` - Current state containing statistics counters and last log time
  #
  # ## Returns
  #   * `{:ok, state}` - If the status updates were successful
  #   * `:retry` - If the database transaction failed
  @spec run([message_in_queue()], ops_state()) :: {:ok, ops_state()} | :retry
  def run(messages_with_blocks, state) do
    highest_committed_block = ArbitrumSettlement.get_highest_committed_block() || -1
    highest_confirmed_block = ArbitrumSettlement.get_highest_confirmed_block() || -1

    log_info("Current bucket contains #{length(messages_with_blocks)} of #{state.max_batch_size} messages")

    {messages_to_confirm, messages_to_commit, messages_to_retry} =
      messages_with_blocks
      |> Enum.reduce({[], [], []}, &process_message(&1, &2, highest_confirmed_block, highest_committed_block))

    log_info(
      "To confirm: #{length(messages_to_confirm)}, To commit: #{length(messages_to_commit)}, To return to the queue: #{length(messages_to_retry)}"
    )

    multi =
      Multi.new()
      |> maybe_update_as_confirmed(messages_to_confirm)
      |> maybe_update_as_sent(messages_to_commit)

    case Explorer.Repo.transaction(multi) do
      {:ok, result} ->
        new_state = update_state_with_results_and_log(state, result)

        # BufferedTask.buffer is used instead of returning {:retry, messages} because:
        # 1. {:retry, messages} would cause BufferedTask to immediately spawn the
        #    next task to process these messages
        # 2. a delay between task runs is required in order to allow the CPU to idle
        if messages_to_retry != [] do
          BufferedTask.buffer(__MODULE__, messages_to_retry, false)
        end

        {:ok, new_state}

      {:error, _, _, _} ->
        :retry
    end
  end

  # Updates state with transaction results and logs statistics if needed
  @spec update_state_with_results_and_log(ops_state(), map()) :: ops_state()
  defp update_state_with_results_and_log(state, result) do
    # Extract counts from update_all results which return {count, nil} tuples
    confirmed_count = (result[:confirmed_messages] && elem(result.confirmed_messages, 0)) || 0
    sent_count = (result[:sent_messages] && elem(result.sent_messages, 0)) || 0

    log_debug("Confirmed: #{confirmed_count}, Sent: #{sent_count}")

    # Update state with new counts
    updated_state = %{
      state
      | confirmed_counter: state.confirmed_counter + confirmed_count,
        sent_counter: state.sent_counter + sent_count
    }

    # Check if we should log statistics
    maybe_log_statistics(updated_state)
  end

  # Manages statistics logging with a "dead hand" timer approach.
  # This function ensures that:
  # - Statistics are logged regularly during active periods
  # - A final statistics log occurs after activity stops
  # - No resources are consumed during idle periods
  # - Each new burst of activity starts its own timing window
  @spec maybe_log_statistics(ops_state()) :: ops_state()
  defp maybe_log_statistics(state) do
    # Cancel existing timer if any
    if state.statistics_timer do
      Process.cancel_timer(state.statistics_timer)
    end

    # Schedule new timer to log statistics if `run` is not called due to
    # empty queue
    timer_ref = Process.send_after(self(), :log_statistics, @log_interval)
    state_with_ref = %{state | statistics_timer: timer_ref}

    now = DateTime.utc_now()

    # Initialize last_log_time if this is the first activity
    state_with_log_time =
      if is_nil(state_with_ref.last_log_time), do: %{state_with_ref | last_log_time: now}, else: state_with_ref

    # Statistics are logged every `@log_interval` seconds
    if not is_nil(state_with_log_time.last_log_time) and
         DateTime.diff(now, state_with_log_time.last_log_time, :second) >= @log_interval / 1000 do
      state_with_log_time
      |> Map.put(:last_log_time, now)
      |> do_log_statistics()
    else
      state_with_log_time
    end
  end

  # Common function to log statistics if counters are non-zero
  @spec do_log_statistics(ops_state()) :: ops_state()
  defp do_log_statistics(%{confirmed_counter: confirmed, sent_counter: sent} = state) do
    if confirmed > 0 || sent > 0 do
      Logger.info("L2-to-L1 message statistics: confirmed = #{confirmed}, sent = #{sent}")
      %{state | confirmed_counter: 0, sent_counter: 0}
    else
      state
    end
  end

  @doc """
    Asynchronously schedules the status reconciliation of L2-to-L1 messages.

    This function takes a list of messages and schedules them for status reconciliation
    based on their originating block numbers and the current state of the rollup chain.
    Only messages directed from L2 to L1 are processed.

    ## Parameters
    - `messages`: A list of messages to be scheduled for status reconciliation.

    ## Returns
    - `:ok`
  """
  @spec async_status_reconcile([Message.to_import()]) :: :ok
  def async_status_reconcile(messages) do
    # Do nothing in case if the indexing chain is not Arbitrum or the feature is disabled.
    if L2ToL1StatusReconcilerSupervisor.disabled?() do
      :ok
    else
      messages_to_process =
        messages
        |> Enum.filter(fn message -> message.direction == :from_l2 end)
        |> Enum.map(fn message ->
          {message.message_id, message.originating_transaction_block_number}
        end)

      unless messages_to_process == [] do
        BufferedTask.buffer(__MODULE__, messages_to_process, false)
      end

      :ok
    end
  end

  # Updates the status of L2-to-L1 messages to `:confirmed` if they meet specific criteria.
  #
  # This function explicitly checks the current status of messages to ensure they
  # are only in `:initiated` or `:sent` states before updating them to `:confirmed`.
  # This safety check prevents accidental status regression (in case a message
  # completion is indexed before the message is picked up by the block fetcher or
  # a message appears in the queue multiple times) when it has already progressed
  # to a higher status (`:confirmed` or `:relayed`).
  #
  # ## Parameters
  #   * `multi` - The Ecto.Multi struct to which this update will be added
  #   * `message_ids` - List of message IDs to potentially update
  #
  # ## Returns
  #   * The updated Ecto.Multi struct with the confirmation update added (if any messages to update)
  #   * The unchanged Ecto.Multi struct if no messages to update
  @spec maybe_update_as_confirmed(Ecto.Multi.t(), [non_neg_integer()]) :: Ecto.Multi.t()
  defp maybe_update_as_confirmed(multi, message_ids)

  defp maybe_update_as_confirmed(multi, []), do: multi

  defp maybe_update_as_confirmed(multi, message_ids) do
    Multi.update_all(
      multi,
      :confirmed_messages,
      from(msg in Message,
        where:
          msg.message_id in ^message_ids and
            msg.direction == :from_l2 and
            msg.status in [:initiated, :sent]
      ),
      set: [
        status: :confirmed,
        updated_at: DateTime.utc_now()
      ]
    )
  end

  # Updates the status of L2-to-L1 messages to `:sent` if they meet specific criteria.
  #
  # This function explicitly checks the current status of messages to ensure they
  # are only in the `:initiated` state before updating them to `:sent`. This safety
  # check prevents accidental status regression (in case a message completion is
  # indexed before the message is picked up by the block fetcher or a message
  # appears in the queue multiple times) when it has already progressed to a higher
  # status (`:sent`, `:confirmed`, or `:relayed`).
  #
  # ## Parameters
  #   * `multi` - The Ecto.Multi struct to which this update will be added
  #   * `message_ids` - List of message IDs to potentially update
  #
  # ## Returns
  #   * The updated Ecto.Multi struct with the sent status update added (if any messages to update)
  #   * The unchanged Ecto.Multi struct if no messages to update
  @spec maybe_update_as_sent(Ecto.Multi.t(), [non_neg_integer()]) :: Ecto.Multi.t()
  defp maybe_update_as_sent(multi, message_ids)

  defp maybe_update_as_sent(multi, []), do: multi

  defp maybe_update_as_sent(multi, message_ids) do
    Multi.update_all(
      multi,
      :sent_messages,
      from(msg in Message,
        where:
          msg.message_id in ^message_ids and
            msg.direction == :from_l2 and
            msg.status == :initiated
      ),
      set: [
        status: :sent,
        updated_at: DateTime.utc_now()
      ]
    )
  end

  # Final handler in the "dead hand" timer approach - logs remaining statistics.
  # `last_log_time` is reset to allow to the new timer to start as soon as new
  # messages are added to the queue.
  def handle_info(:log_statistics, state) do
    {:noreply, %{state | statistics_timer: nil, last_log_time: nil} |> do_log_statistics()}
  end

  # Process a message based on its type and block number against the current chain state
  @spec process_message(
          message_in_queue(),
          {[non_neg_integer()], [non_neg_integer()], [message_in_queue()]},
          non_neg_integer(),
          non_neg_integer()
        ) ::
          {[non_neg_integer()], [non_neg_integer()], [message_in_queue()]}
  defp process_message(
         {message_id, block_number},
         {confirm, commit, to_retry},
         highest_confirmed_block,
         highest_committed_block
       ) do
    # The order of conditions is crucial for optimal message status transitions:
    # 1. Checking highest_confirmed_block first allows messages to go directly from
    #    :initiated to :confirmed, skipping the intermediate :sent state. This avoids
    #    double status changes (initiated->sent->confirmed) for messages whose
    #    confirmations are already known.
    # 2. The second condition (highest_committed_block) is only evaluated if the first
    #    fails, ensuring we don't unnecessarily process messages for :sent status when
    #    they should be :confirmed (when highest_committed_block <= highest_confirmed_block).
    cond do
      block_number <= highest_confirmed_block ->
        {[message_id | confirm], commit, to_retry}

      block_number <= highest_committed_block ->
        {confirm, [message_id | commit], [{message_id, block_number, :sent} | to_retry]}

      true ->
        {confirm, commit, [{message_id, block_number} | to_retry]}
    end
  end

  defp process_message(
         {message_id, block_number, :sent},
         {confirm, commit, to_retry},
         highest_confirmed_block,
         _highest_committed_block
       ) do
    if block_number <= highest_confirmed_block do
      {[message_id | confirm], commit, to_retry}
    else
      {confirm, commit, [{message_id, block_number, :sent} | to_retry]}
    end
  end
end
