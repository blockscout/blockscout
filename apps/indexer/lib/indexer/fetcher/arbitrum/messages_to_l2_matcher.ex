defmodule Indexer.Fetcher.Arbitrum.MessagesToL2Matcher do
  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  require Logger

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Arbitrum.MessagesToL2Matcher.Supervisor, as: MessagesToL2MatcherSupervisor
  alias Indexer.Fetcher.Arbitrum.Messaging, as: MessagingUtils
  alias Indexer.Fetcher.Arbitrum.Utils.Db
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  @behaviour BufferedTask

  # Since the cache for DB responses is used, it is efficient to get rid of cuncurrent handling of the tasks.
  @default_max_batch_size 10
  @default_max_concurrency 1

  @flush_interval :timer.seconds(1)

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

  @impl BufferedTask
  def run(txs_with_timeouts, %{uncompleted_messages: cached_uncompleted_messages_ids, recheck_interval: _} = state)
      when is_list(txs_with_timeouts) do
    # For next handling only the transactions whith expired timeouts are needed.
    now = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    {txs, delayed_txs} =
      txs_with_timeouts
      |> Enum.reduce({[], []}, fn {timeout, tx}, {txs, delayed_txs} ->
        if timeout > now do
          {txs, [{timeout, tx} | delayed_txs]}
        else
          {[tx | txs], delayed_txs}
        end
      end)

    # Check if the request Id of transactions with expired timeouts matches hashed
    # ids of the uncompleted messages and update the transactions with the decoded
    # request ids. If it required, the cache is updated.
    # Possible outcomes:
    # - no transactions were updated, because the txs list is empty, the cache is updated
    # - no transactions were updated, because no matches in both cache and DB were found, the cache is updated
    # - all matches were found in the cache, the cache is not updated
    # - all matches were found in the DB, the cache is updated
    # - some matches were found in the cache, but not all, the cache is not updated
    {updated?, handled_txs, updated_cache} = update_txs_with_hashed_ids(txs, cached_uncompleted_messages_ids)
    updated_state = %{state | uncompleted_messages: updated_cache}

    case {updated?, txs == []} do
      {false, true} ->
        # There were no transactions with expired timeouts, so counters of the transactions
        # updated and the transactions are scheduled for retry.
        {:retry, delayed_txs, updated_state}

      {false, false} ->
        # Some of the transactions were with expired timeouts, but no matches were found
        # for these transaction in the cache or the DB. Timeouts for such transactions
        # are re-initialized and they are added to the list with tranansactions with
        # updated counters.
        txs_to_retry =
          delayed_txs ++ initialize_timeouts(handled_txs, now + state.recheck_interval)

        {:retry, txs_to_retry, updated_state}

      {true, _} ->
        {messages, txs_to_retry_wo_timeouts} = MessagingUtils.filter_l1_to_l2_messages(handled_txs)

        MessagingUtils.import_to_db(messages)

        if txs_to_retry_wo_timeouts == [] and delayed_txs == [] do
          {:ok, updated_state}
        else
          # Either some of the transactions with expired timeouts don't have a matching
          # request id in the cache or the DB, or there are transactions with non-expired
          # timeouts. All these transactions are needed to be scheduled for retry.
          txs_to_retry =
            delayed_txs ++ initialize_timeouts(txs_to_retry_wo_timeouts, now + state.recheck_interval)

          {:retry, txs_to_retry, updated_state}
        end
    end
  end

  def async_discover_match(txs_with_messages_from_l1) do
    if MessagesToL2MatcherSupervisor.disabled?() do
      :ok
    else
      BufferedTask.buffer(__MODULE__, Enum.map(txs_with_messages_from_l1, &{0, &1}), false)
    end
  end

  defp get_hashed_ids_for_uncompleted_messages do
    Db.get_uncompleted_l1_to_l2_messages_ids()
    |> Enum.reduce(%{}, fn id, acc ->
      Map.put(
        acc,
        ArbitrumHelper.get_hashed_message_id_as_hex_str(id),
        ArbitrumHelper.bytes_to_hex_str(<<id::size(256)>>)
      )
    end)
  end

  defp update_txs_with_hashed_ids([], cache), do: {false, [], cache}

  defp update_txs_with_hashed_ids(txs, cached_uncompleted_messages_ids) do
    # Try to use the cached DB response first. That makes sense if historical
    # messages are being processed (by catchup block fetcher or by the missing
    # messages handler). Since amount of txs provided to this function is limited
    # it OK to inspect the cache before making a DB request.
    case revise_txs_with_hashed_ids(txs, cached_uncompleted_messages_ids, true) do
      {_, false} ->
        # If no matches were found in the cache, try to fetch ucompleted messages from the DB.
        uncompleted_messages = get_hashed_ids_for_uncompleted_messages()

        {updated_txs, updated?} = revise_txs_with_hashed_ids(txs, uncompleted_messages, false)

        {updated?, updated_txs, uncompleted_messages}

      {updated_txs, _} ->
        # There could be a case when some hashed ids were not found since the cache is outdated
        # such txs will be scheduled for retry and the cache will be updated then.
        {true, updated_txs, cached_uncompleted_messages_ids}
    end
  end

  defp revise_txs_with_hashed_ids(txs, uncompleted_messages, report?) do
    txs
    |> Enum.reduce({[], false}, fn tx, {updated_txs, updated?} ->
      if report?, do: log_info("Attempting to decode the request id #{tx.request_id} in the tx #{tx.hash}")

      case Map.get(uncompleted_messages, tx.request_id) do
        nil ->
          {[tx | updated_txs], updated?}

        id ->
          {[%{tx | request_id: id} | updated_txs], true}
      end
    end)
  end

  defp initialize_timeouts(txs_to_retry, timeout) do
    txs_to_retry
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
