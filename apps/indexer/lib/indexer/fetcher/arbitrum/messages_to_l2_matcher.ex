defmodule Indexer.Fetcher.Arbitrum.MessagesToL2Matcher do
  @moduledoc """
  Matches and processes L1-to-L2 messages in the Arbitrum protocol.

  This module implements a buffered task system to handle the matching of
  L1-to-L2 messages with hashed message IDs. It periodically attempts to match
  unmatched messages, imports matched messages to the database, and reschedules
  unmatched messages for future processing.

  The matcher operates asynchronously, allowing for efficient handling of
  messages even when corresponding L1 transactions are not yet indexed. This
  approach prevents blocking the discovery process and ensures eventual
  consistency in message matching.

  Key features:
  - Implements the `BufferedTask` behavior for efficient batch processing.
  - Maintains a cache of uncompleted message IDs to optimize matching.
  - Provides functionality to asynchronously schedule message matching.
  - Automatically retries unmatched messages based on a configurable interval.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  require Logger

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.MessagesToL2Matcher.Supervisor, as: MessagesToL2MatcherSupervisor
  alias Indexer.Fetcher.Arbitrum.Messaging, as: MessagingUtils
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  @behaviour BufferedTask

  # Since the cache for DB responses is used, it is efficient to get rid of concurrent handling of the tasks.
  @default_max_batch_size 10
  @default_max_concurrency 1

  @flush_interval :timer.seconds(1)

  @typep min_transaction :: %{
           :hash => binary(),
           :type => non_neg_integer(),
           optional(:request_id) => non_neg_integer(),
           optional(any()) => any()
         }

  @doc """
    Defines the child specification for the MessagesToL2Matcher.

    This function creates a child specification for use in a supervision tree,
    configuring a `BufferedTask` process for the MessagesToL2Matcher. It sets up
    the initial state and options for the task, including the recheck interval
    for matching L1-to-L2 messages.

    Using the same value for discovering new L1 messages interval and for the
    unmatched L2 messages recheck interval ensures that message matching attempts
    are synchronized with the rate of new L1 message discovery, optimizing the
    process by avoiding unnecessary rechecks when no new L1 messages have been
    added to the database.

    ## Parameters
    - `init_options`: A keyword list of initial options for the BufferedTask.
    - `gen_server_options`: A keyword list of options for the underlying GenServer.

    ## Returns
    A child specification map suitable for use in a supervision tree, with the
    following key properties:
    - Uses `BufferedTask` as the module to start.
    - Configures the MessagesToL2Matcher as the callback module for the BufferedTask.
    - Sets the initial state with an empty cache of IDs of uncompleted messages and
      the recheck interval from the Arbitrum.TrackingMessagesOnL1 configuration.
    - Merges provided options with default options for the BufferedTask.
    - Uses this module's name as the child's id in the supervision tree.
  """
  def child_spec([init_options, gen_server_options]) do
    messages_on_l1_interval =
      Application.get_all_env(:indexer)[Indexer.Fetcher.Arbitrum.TrackingMessagesOnL1][:recheck_interval]

    buffered_task_init_options =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(
        state: %{
          uncompleted_messages: %{},
          recheck_interval: messages_on_l1_interval
        }
      )

    Supervisor.child_spec({BufferedTask, [{__MODULE__, buffered_task_init_options}, gen_server_options]},
      id: __MODULE__
    )
  end

  @impl BufferedTask
  def init(initial, _, _) do
    initial
  end

  @doc """
    Processes a batch of transactions with hashed message IDs for L1-to-L2 messages.

    This function, implementing the `BufferedTask` behavior, handles a list of
    transactions with associated timeouts. It attempts to match hashed request IDs
    with uncompleted L1-to-L2 messages, updates the transactions accordingly, and
    imports any successfully matched messages to the database.

    The function performs the following steps:
    1. Separates transactions with expired timeouts from those still delayed.
    2. Attempts to update expired transactions by matching their hashed request IDs.
    3. Processes updated transactions to filter and import L1-to-L2 messages.
    4. Reschedules unmatched or delayed transactions for future processing.

    For unmatched transactions, new timeouts are set to the current time increased
    by the value of the recheck interval.

    ## Parameters
    - `transactions_with_timeouts`: A list of tuples, each containing a timeout and a
      transaction with a potentially hashed request ID.
    - `state`: The current state of the task, including cached IDs of uncompleted
      messages and the recheck interval.

    ## Returns
    - `{:ok, updated_state}` if all transactions were processed successfully and
      no retries are needed.
    - `{:retry, transactions_to_retry, updated_state}` if some transactions need to be
      retried, either due to unmatched request IDs or unexpired timeouts.

    The returned state always includes an updated cache of IDs of uncompleted
    messages.
  """
  @impl BufferedTask
  @spec run([{non_neg_integer(), min_transaction()}], %{
          :recheck_interval => non_neg_integer(),
          :uncompleted_messages => %{binary() => binary()},
          optional(any()) => any()
        }) ::
          {:ok, %{:uncompleted_messages => %{binary() => binary()}, optional(any()) => any()}}
          | {:retry, [{non_neg_integer(), min_transaction()}],
             %{:uncompleted_messages => %{binary() => binary()}, optional(any()) => any()}}
  def run(
        transactions_with_timeouts,
        %{uncompleted_messages: cached_uncompleted_messages_ids, recheck_interval: _} = state
      )
      when is_list(transactions_with_timeouts) do
    # For next handling only the transactions with expired timeouts are needed.
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {transactions, delayed_transactions} =
      transactions_with_timeouts
      |> Enum.reduce({[], []}, fn {timeout, transaction}, {transactions, delayed_transactions} ->
        if timeout > now do
          {transactions, [{timeout, transaction} | delayed_transactions]}
        else
          {[transaction | transactions], delayed_transactions}
        end
      end)

    # Check if the request Id of transactions with expired timeouts matches hashed
    # ids of the uncompleted messages and update the transactions with the decoded
    # request ids. If it required, the cache is updated.
    # Possible outcomes:
    # - no transactions were updated, because the transactions list is empty, the cache is updated
    # - no transactions were updated, because no matches in both cache and DB were found, the cache is updated
    # - all matches were found in the cache, the cache is not updated
    # - all matches were found in the DB, the cache is updated
    # - some matches were found in the cache, but not all, the cache is not updated
    {updated?, handled_transactions, updated_cache} =
      update_transactions_with_hashed_ids(transactions, cached_uncompleted_messages_ids)

    updated_state = %{state | uncompleted_messages: updated_cache}

    case {updated?, transactions == []} do
      {false, true} ->
        # There were no transactions with expired timeouts, so counters of the transactions
        # updated and the transactions are scheduled for retry.
        {:retry, delayed_transactions, updated_state}

      {false, false} ->
        # Some of the transactions were with expired timeouts, but no matches were found
        # for these transaction in the cache or the DB. Timeouts for such transactions
        # are re-initialized and they are added to the list with transactions with
        # updated counters.
        transactions_to_retry =
          delayed_transactions ++ initialize_timeouts(handled_transactions, now + state.recheck_interval)

        {:retry, transactions_to_retry, updated_state}

      {true, _} ->
        {messages, transactions_to_retry_wo_timeouts} = MessagingUtils.filter_l1_to_l2_messages(handled_transactions)

        MessagingUtils.import_to_db(messages)

        if transactions_to_retry_wo_timeouts == [] and delayed_transactions == [] do
          {:ok, updated_state}
        else
          # Either some of the transactions with expired timeouts don't have a matching
          # request id in the cache or the DB, or there are transactions with non-expired
          # timeouts. All these transactions are needed to be scheduled for retry.
          transactions_to_retry =
            delayed_transactions ++ initialize_timeouts(transactions_to_retry_wo_timeouts, now + state.recheck_interval)

          {:retry, transactions_to_retry, updated_state}
        end
    end
  end

  @doc """
    Asynchronously schedules the discovery of matches for L1-to-L2 messages.

    This function schedules the processing of transactions with hashed message IDs that
    require further matching.

    ## Parameters
    - `transactions_with_messages_from_l1`: A list of transactions containing L1-to-L2
      messages with hashed message IDs.

    ## Returns
    - `:ok`
  """
  @spec async_discover_match([min_transaction()]) :: :ok
  def async_discover_match(transactions_with_messages_from_l1) do
    # Do nothing in case if the indexing chain is not Arbitrum or the feature is disabled.
    if MessagesToL2MatcherSupervisor.disabled?() do
      :ok
    else
      BufferedTask.buffer(__MODULE__, Enum.map(transactions_with_messages_from_l1, &{0, &1}), false)
    end
  end

  # Retrieves and transforms uncompleted L1-to-L2 message IDs into a map of hashed IDs.
  #
  # This function fetches the IDs of uncompleted L1-to-L2 messages and creates a map
  # where each key is the hashed hexadecimal string representation of a message ID,
  # and the corresponding value is the original ID converted to a hexadecimal string.
  #
  # ## Returns
  # A map where:
  # - Keys are hashed message IDs as hexadecimal strings.
  # - Values are original message IDs as 256-bit hexadecimal strings.
  @spec get_hashed_ids_for_uncompleted_messages() :: %{binary() => binary()}
  defp get_hashed_ids_for_uncompleted_messages do
    DbMessages.get_uncompleted_l1_to_l2_messages_ids()
    |> Enum.reduce(%{}, fn id, acc ->
      Map.put(
        acc,
        ArbitrumHelper.get_hashed_message_id_as_hex_str(id),
        ArbitrumHelper.bytes_to_hex_str(<<id::size(256)>>)
      )
    end)
  end

  # Updates transactions with hashed request IDs, using cached or fresh data.
  #
  # This function attempts to replace hashed request IDs in transactions with their
  # original IDs. It first tries using a cached set of uncompleted message IDs. If
  # no matches are found in the cache, it fetches fresh data from the database.
  #
  # ## Parameters
  # - `transactions`: A list of transactions with potentially hashed request IDs.
  # - `cached_uncompleted_messages_ids`: A map of cached hashed message IDs to their
  #   original forms.
  #
  # ## Returns
  # A tuple containing:
  # - A boolean indicating whether any transactions were updated.
  # - An updated list of transactions, with some request IDs potentially replaced.
  # - The map of uncompleted message IDs used for the update (either the cache or
  #   freshly fetched data).
  #
  # ## Notes
  # - If the cache is used successfully, it's returned as-is, even if potentially
  #   outdated.
  # - If the cache fails, fresh data is fetched and returned, updating the cache.
  @spec update_transactions_with_hashed_ids([min_transaction()], %{binary() => binary()}) ::
          {boolean(), [min_transaction()], %{binary() => binary()}}
  defp update_transactions_with_hashed_ids([], cache), do: {false, [], cache}

  defp update_transactions_with_hashed_ids(transactions, cached_uncompleted_messages_ids) do
    # Try to use the cached DB response first. That makes sense if historical
    # messages are being processed (by catchup block fetcher or by the missing
    # messages handler). Since amount of transactions provided to this function is limited
    # it OK to inspect the cache before making a DB request.
    case revise_transactions_with_hashed_ids(transactions, cached_uncompleted_messages_ids, true) do
      {_, false} ->
        # If no matches were found in the cache, try to fetch uncompleted messages from the DB.
        uncompleted_messages = get_hashed_ids_for_uncompleted_messages()

        {updated_transactions, updated?} =
          revise_transactions_with_hashed_ids(transactions, uncompleted_messages, false)

        {updated?, updated_transactions, uncompleted_messages}

      {updated_transactions, _} ->
        # There could be a case when some hashed ids were not found since the cache is outdated
        # such transactions will be scheduled for retry and the cache will be updated then.
        {true, updated_transactions, cached_uncompleted_messages_ids}
    end
  end

  # Attempts to replace hashed request IDs in transactions with their original IDs.
  #
  # This function iterates through a list of transactions, trying to match their
  # hashed request IDs with entries in the provided map of uncompleted messages.
  # If a match is found, the transaction's request ID is updated to its original
  # (non-hashed) form.
  #
  # ## Parameters
  # - `transactions`: A list of transactions with potentially hashed request IDs.
  # - `uncompleted_messages`: A map of hashed message IDs to their original forms.
  # - `report?`: A boolean flag indicating whether to log decoding attempts.
  #
  # ## Returns
  # A tuple containing:
  # - An updated list of transactions, with some request IDs potentially replaced.
  # - A boolean indicating whether any transactions were updated.
  @spec revise_transactions_with_hashed_ids([min_transaction()], %{binary() => binary()}, boolean()) ::
          {[min_transaction()], boolean()}
  defp revise_transactions_with_hashed_ids(transactions, uncompleted_messages, report?) do
    transactions
    |> Enum.reduce({[], false}, fn transaction, {updated_transactions, updated?} ->
      if report?,
        do:
          log_info(
            "Attempting to decode the request id #{transaction.request_id} in the transaction #{transaction.hash}"
          )

      case Map.get(uncompleted_messages, transaction.request_id) do
        nil ->
          {[transaction | updated_transactions], updated?}

        id ->
          {[%{transaction | request_id: id} | updated_transactions], true}
      end
    end)
  end

  # Assigns a uniform timeout to each transaction in the given list.
  @spec initialize_timeouts([min_transaction()], non_neg_integer()) :: [{non_neg_integer(), min_transaction()}]
  defp initialize_timeouts(transactions_to_retry, timeout) do
    transactions_to_retry
    |> Enum.map(&{timeout, &1})
  end

  defp defaults do
    [
      flush_interval: @flush_interval,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      poll: false,
      task_supervisor: __MODULE__.TaskSupervisor,
      metadata: [fetcher: :messages_to_l2_matcher]
    ]
  end
end
