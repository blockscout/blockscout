# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Etherscan.Logs do
  @moduledoc """
  This module contains functions for working with logs, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{DenormalizationHelper, Log}

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

  def list_logs(%{address_hash: address_hash} = filter, paging_options) when not is_nil(address_hash) do
    paging_options = if is_nil(paging_options), do: @default_paging_options, else: paging_options
    prepared_filter = Map.merge(@base_filter, filter)

    # With `union_multiple_values: true` `where_topic_match/3` may turn the
    # query into a UNION ALL, so it must be applied last: `where/3` on a
    # combination query would only affect its first branch.
    logs_query =
      Log
      |> Log.address_match_query(address_hash)
      |> where([log], log.block_number >= ^prepared_filter.from_block)
      |> where([log], log.block_number <= ^prepared_filter.to_block)
      |> page_logs(paging_options)
      |> where_topic_match(prepared_filter, union_multiple_values: true)

    logs_query
    |> join_transaction_data()
    |> limit(1000)
    |> fetch_ordered()
    |> Log.preload_block()
    |> Log.preload_transaction([], Repo.replica())
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
      |> where_consensus()
      |> page_logs(paging_options)
      |> order_by([log], asc: log.block_number, asc: log.index)
      |> limit(1000)

    logs_query
    |> join_transaction_data()
    |> fetch_ordered()
  end

  # Keeps only logs whose consensus predicate matches the one applied by
  # `join_transaction_data/1` in the current denormalization state. Logs are
  # joined to transactions through `Log.join_transaction_query/1` in both
  # places, so each check is a few index lookups per candidate log.
  # `transactions.block_consensus` can diverge from `blocks.consensus` (see
  # `Explorer.Migrator.TransactionBlockConsensus`), which is why the predicate
  # is not simply `blocks.consensus` in both states.
  defp where_consensus(logs_query) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      logs_query
      |> Log.join_transaction_query()
      |> where(as(:transaction).block_consensus == true)
    else
      logs_query
      |> Log.join_transaction_query()
      |> join(:inner, [transaction: transaction], block in assoc(transaction, :block), as: :block)
      |> where(as(:block).consensus == true)
    end
  end

  # Re-selects the joined query through an outer subquery so that fields
  # taken from the `logs` subquery are loaded with their schema types (`Hash`
  # structs instead of raw binaries), then applies the final ordering and fills
  # `data` and `first_topic` of logs stored with `compressed_data` and
  # `first_topic_id` only.
  defp fetch_ordered(query) do
    query
    |> Chain.wrapped_union_subquery()
    |> order_by([log], asc: log.block_number, asc: log.index)
    |> Repo.replica().all()
    |> Log.prepare_data()
    |> Log.prepare_first_topic()
  end

  # Wraps `logs_query` in a subquery and joins each log to its consensus
  # transaction through `Log.join_transaction_query/1`, a few index lookups per
  # log. The selected shape is identical in both denormalization states.
  defp join_transaction_data(logs_query) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      logs_query
      |> subquery()
      |> Log.join_transaction_query()
      |> Log.join_address_mapping_query()
      |> where(as(:transaction).block_consensus == true)
      |> select([log], map(log, ^@log_fields))
      |> select_merge([log], %{
        gas_price: as(:transaction).gas_price,
        gas_used: as(:transaction).gas_used,
        transaction_index: as(:transaction).index,
        block_hash: as(:transaction).block_hash,
        block_number: as(:transaction).block_number,
        block_timestamp: as(:transaction).block_timestamp,
        block_consensus: as(:transaction).block_consensus,
        transaction_hash: as(:transaction).hash,
        address_hash: coalesce(log.address_hash, as(:address_mapping).address_hash)
      })
      |> order_by([log], asc: log.block_number, asc: log.index)
    else
      logs_query
      |> subquery()
      |> Log.join_transaction_query()
      |> Log.join_address_mapping_query()
      |> join(:inner, [l, t], block in assoc(t, :block))
      |> where([_l, _t, _am, block], block.consensus == true)
      |> select([log], map(log, ^@log_fields))
      |> select_merge([log, transaction, address_mapping, block], %{
        gas_price: transaction.gas_price,
        gas_used: transaction.gas_used,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        block_timestamp: block.timestamp,
        block_consensus: block.consensus,
        transaction_hash: transaction.hash,
        address_hash: coalesce(log.address_hash, address_mapping.address_hash)
      })
      |> order_by([log, _t, _am, _b], asc: log.block_number, asc: log.index)
    end
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
        where_multiple_topics_match(query, filter)
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

  defp where_multiple_topics_match(query, filter) do
    Enum.reduce(Map.keys(@topic_operations), query, fn topic_operation, acc_query ->
      where_multiple_topics_match(acc_query, filter, topic_operation, filter[topic_operation])
    end)
  end

  defp where_multiple_topics_match(query, filter, topic_operation, "and") do
    {topic_a, topic_b} = @topic_operations[topic_operation]

    dynamic =
      dynamic(
        [l],
        ^Log.topic_filter_dynamic(topic_a, [filter[topic_a]]) and
          ^Log.topic_filter_dynamic(topic_b, List.wrap(filter[topic_b]))
      )

    where(query, [l], ^dynamic)
  end

  defp where_multiple_topics_match(query, filter, topic_operation, "or") do
    {topic_a, topic_b} = @topic_operations[topic_operation]
    where(query, [l], ^Log.filter_by_topic_dynamic([topic_a, topic_b], [[filter[topic_a]], List.wrap(filter[topic_b])]))
  end

  defp where_multiple_topics_match(query, _, _, _), do: query

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
