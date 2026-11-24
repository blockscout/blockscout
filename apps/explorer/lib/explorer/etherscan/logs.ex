# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Etherscan.Logs do
  @moduledoc """
  This module contains functions for working with logs, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{DenormalizationHelper, Hash, Log}

  @base_filter %{
    from_block: nil,
    to_block: nil,
    address_hash: nil,
    first_topic: nil,
    second_topic: nil,
    third_topic: nil,
    fourth_topic: nil,
    topic0_1_opr: nil,
    topic0_2_opr: nil,
    topic0_3_opr: nil,
    topic1_2_opr: nil,
    topic1_3_opr: nil,
    topic2_3_opr: nil
  }

  @log_fields [
    :data,
    :compressed_data,
    :first_topic,
    :first_topic_id,
    :second_topic,
    :third_topic,
    :fourth_topic,
    :index
  ]

  @default_paging_options %{block_number: nil, log_index: nil}

  @doc """
  Gets a list of logs that meet the criteria in a given filter map.

  Required filter parameters:

  * `from_block`
  * `to_block`
  * `address_hash` and/or `{x}_topic`
  * When multiple `{x}_topic` params are provided, then the corresponding
  `topic{x}_{x}_opr` param is required. For example, if "first_topic" and
  "second_topic" are provided, then "topic0_1_opr" is required.

  Supported `{x}_topic`s:

  * first_topic
  * second_topic
  * third_topic
  * fourth_topic

  Supported `topic{x}_{x}_opr`s:

  * topic0_1_opr
  * topic0_2_opr
  * topic0_3_opr
  * topic1_2_opr
  * topic1_3_opr
  * topic2_3_opr

  """
  @spec list_logs(map()) :: [map()]
  def list_logs(filter, paging_options \\ @default_paging_options)

  # The address is matched through `Log.address_match_union_query/3`, one
  # `UNION ALL` branch per address condition. While the optimized fields
  # migration is in progress, a log of the address is matched either by
  # `address_id` or by the legacy `address_hash`, and a single `OR` condition
  # makes the planner collect and sort every log of the address in the block
  # range before the LIMIT. Each branch is ordered and limited on its own
  # instead, so it stays an ordered index scan that stops at the LIMIT.
  #
  # Each branch matches the topics and joins the transactions by the fields its
  # logs are stored with (see `t:Explorer.Chain.Log.storage/0`). Conditions
  # over both formats, such as `first_topic_id = $1 OR first_topic = $2`, keep
  # the `address_id` composite indexes from being used and make every
  # transaction lookup a `BitmapOr` of two index scans.
  #
  # Since the LIMIT is applied inside the branches, consensus is checked there,
  # for the reasons given for the topic-only clause below, and the page fields
  # are selected from the same transaction join, so each log of the page is
  # looked up in `transactions` once.
  def list_logs(%{address_hash: address_hash} = filter, paging_options) when not is_nil(address_hash) do
    paging_options = if is_nil(paging_options), do: @default_paging_options, else: paging_options
    prepared_filter = Map.merge(@base_filter, filter)

    address_hash
    |> Log.address_match_union_query(
      fn address_match_dynamic, storage ->
        # With `union_multiple_values: true` `where_topic_match/3` may turn the
        # branch into a UNION ALL, so it is applied last and the branch is
        # wrapped into a subquery: `where/3` and `select/3` on a combination
        # query would only affect its first branch, and a combination can only
        # be ordered through a subquery.
        Log
        |> where(^address_match_dynamic)
        |> where([log], log.block_number >= ^prepared_filter.from_block)
        |> where([log], log.block_number <= ^prepared_filter.to_block)
        |> join_consensus_transaction(storage)
        |> page_logs(paging_options)
        |> select_page_fields(%{
          # every log of the branch belongs to the filtered address
          address_hash: dynamic(type(^address_hash, Hash.Address)),
          # the branch is ordered by the selected block number, which is taken
          # from the log so that an index on `logs` returns the rows in order
          block_number: dynamic([log], log.block_number)
        })
        |> where_topic_match(prepared_filter, union_multiple_values: true, storage: storage)
        |> Chain.wrapped_union_subquery()
      end,
      &order_and_limit/1
    )
    |> fetch()
  end

  # Since address_hash was not present, we know that a topic filter has been
  # applied. Ordering, paging and the LIMIT are applied inside a subquery over
  # `logs` (with only the consensus check joined), so the planner has to
  # produce at most 1000 logs before joining the transaction data. Joining
  # first and limiting afterwards lets the planner scan the whole
  # `transactions` block range up front, which is prohibitively slow for wide
  # ranges.
  #
  # Logs of non-consensus blocks are not guaranteed to be deleted (see
  # `Explorer.Migrator.DeleteNonConsensusLogs`), so consensus has to be checked
  # before the LIMIT: otherwise a page could come back short, or empty with no
  # cursor to continue from, while later consensus logs still exist. The check
  # uses the same join and predicate as `join_transaction_data/1`, so no row
  # that makes it into the page is dropped by the outer join afterwards.
  def list_logs(filter, paging_options) do
    paging_options = if is_nil(paging_options), do: @default_paging_options, else: paging_options
    prepared_filter = Map.merge(@base_filter, filter)

    logs_query =
      Log
      |> where_topic_match(prepared_filter)
      |> where([log], log.block_number >= ^prepared_filter.from_block)
      |> where([log], log.block_number <= ^prepared_filter.to_block)
      |> join_consensus_transaction()
      |> page_logs(paging_options)
      |> order_and_limit()

    logs_query
    |> join_transaction_data()
    |> fetch_ordered()
  end

  defp order_and_limit(logs_query) do
    logs_query
    |> order_by([log], asc: log.block_number, asc: log.index)
    |> limit(1000)
  end

  # Joins every log to its transaction through `Log.join_transaction_query/2`,
  # a few index lookups per log, and keeps only consensus ones: by
  # `transactions.block_consensus` once the transactions denormalization has
  # finished, by `blocks.consensus` before that. `transactions.block_consensus`
  # can diverge from `blocks.consensus` (see
  # `Explorer.Migrator.TransactionBlockConsensus`), which is why the predicate
  # is not simply `blocks.consensus` in both states. The topic-only clause
  # checks consensus inside the page subquery and again in
  # `join_transaction_data/1` with the same join and predicate, so no row that
  # makes it into the page is dropped by the outer join.
  defp join_consensus_transaction(logs_query, storage \\ nil) do
    logs_query = Log.join_transaction_query(logs_query, storage)

    if DenormalizationHelper.transactions_denormalization_finished?() do
      where(logs_query, as(:transaction).block_consensus == true)
    else
      logs_query
      |> join(:inner, [transaction: transaction], block in assoc(transaction, :block), as: :block)
      |> where(as(:block).consensus == true)
    end
  end

  # Selects the log fields and every transaction and block field that the
  # `getLogs` and `eth_getLogs` renderers use, so the logs need no further
  # preloads. Expects the bindings of `join_consensus_transaction/2`; the
  # selected shape is identical in both denormalization states. `fields` adds
  # or overrides the selected fields.
  defp select_page_fields(query, fields) do
    block_fields =
      if has_named_binding?(query, :block) do
        %{block_timestamp: dynamic(as(:block).timestamp), block_consensus: dynamic(as(:block).consensus)}
      else
        %{
          block_timestamp: dynamic(as(:transaction).block_timestamp),
          block_consensus: dynamic(as(:transaction).block_consensus)
        }
      end

    selected_fields =
      %{
        gas_price: dynamic(as(:transaction).gas_price),
        gas_used: dynamic(as(:transaction).gas_used),
        transaction_index: dynamic(as(:transaction).index),
        block_hash: dynamic(as(:transaction).block_hash),
        block_number: dynamic(as(:transaction).block_number),
        transaction_hash: dynamic(as(:transaction).hash)
      }
      |> Map.merge(block_fields)
      |> Map.merge(fields)

    query
    |> select([log], map(log, ^@log_fields))
    |> select_merge(^selected_fields)
  end

  # Re-selects the joined query through an outer subquery so that fields
  # taken from the `logs` subquery are loaded with their schema types (`Hash`
  # structs instead of raw binaries), then applies the final ordering.
  defp fetch_ordered(query) do
    query
    |> Chain.wrapped_union_subquery()
    |> order_by([log], asc: log.block_number, asc: log.index)
    |> fetch()
  end

  # Fills `data` and `first_topic` of logs stored with `compressed_data` and
  # `first_topic_id` only.
  defp fetch(query) do
    query
    |> Repo.replica().all()
    |> Log.prepare_data()
    |> Log.prepare_first_topic(api?: true)
  end

  # Wraps `logs_query` in a subquery and joins each log to its consensus
  # transaction to select the page fields.
  defp join_transaction_data(logs_query) do
    logs_query
    |> subquery()
    |> join_consensus_transaction()
    |> Log.join_address_mapping_query()
    |> select_page_fields(%{
      address_hash: dynamic([log], coalesce(log.address_hash, as(:address_mapping).address_hash))
    })
    |> order_by([log], asc: log.block_number, asc: log.index)
  end

  @topics [
    :first_topic,
    :second_topic,
    :third_topic,
    :fourth_topic
  ]

  @topic_operations %{
    topic0_1_opr: {:first_topic, :second_topic},
    topic0_2_opr: {:first_topic, :third_topic},
    topic0_3_opr: {:first_topic, :fourth_topic},
    topic1_2_opr: {:second_topic, :third_topic},
    topic1_3_opr: {:second_topic, :fourth_topic},
    topic2_3_opr: {:third_topic, :fourth_topic}
  }

  defp where_topic_match(query, filter, opts \\ []) do
    filter = sanitize_filter_topics(filter)

    case Enum.filter(@topics, &filter[&1]) do
      [] ->
        query

      [topic] ->
        Log.filter_by_topic_query(query, topic, filter[topic], opts)

      _ ->
        where_multiple_topics_match(query, filter, opts[:storage])
    end
  end

  defp sanitize_filter_topics(filter) do
    @topics
    |> Enum.reduce(filter, fn topic, acc ->
      topic_value = filter[topic]

      sanitized_value =
        topic_value
        |> List.wrap()
        |> Enum.map(&sanitize_topic_value/1)
        |> Enum.reject(&is_nil/1)
        |> case do
          [] -> nil
          [topic] -> topic
          topics -> topics
        end

      Map.put(acc, topic, sanitized_value)
    end)
  end

  defp sanitize_topic_value(topic_value) do
    case topic_value do
      %Explorer.Chain.Hash{} ->
        topic_value

      _ ->
        sanitize_string_topic_value(topic_value)
    end
  end

  defp sanitize_string_topic_value(topic_value) do
    case Chain.string_to_full_hash(topic_value) do
      {:ok, _} ->
        topic_value

      _ ->
        nil
    end
  end

  defp where_multiple_topics_match(query, filter, storage) do
    Enum.reduce(Map.keys(@topic_operations), query, fn topic_operation, acc_query ->
      where_multiple_topics_match(acc_query, filter, topic_operation, filter[topic_operation], storage)
    end)
  end

  defp where_multiple_topics_match(query, filter, topic_operation, "and", storage) do
    {topic_a, topic_b} = @topic_operations[topic_operation]

    dynamic =
      dynamic(
        [l],
        ^Log.topic_filter_dynamic(topic_a, [filter[topic_a]], storage) and
          ^Log.topic_filter_dynamic(topic_b, List.wrap(filter[topic_b]), storage)
      )

    where(query, [l], ^dynamic)
  end

  defp where_multiple_topics_match(query, filter, topic_operation, "or", storage) do
    {topic_a, topic_b} = @topic_operations[topic_operation]
    topic_values_list = [[filter[topic_a]], List.wrap(filter[topic_b])]
    where(query, [l], ^Log.filter_by_topic_dynamic([topic_a, topic_b], topic_values_list, storage))
  end

  defp where_multiple_topics_match(query, _, _, _, _), do: query

  defp page_logs(query, %{block_number: nil, log_index: nil}) do
    query
  end

  defp page_logs(query, %{block_number: block_number, log_index: log_index}) do
    from(
      data in query,
      where: {data.block_number, data.index} > {^block_number, ^log_index}
    )
  end
end
