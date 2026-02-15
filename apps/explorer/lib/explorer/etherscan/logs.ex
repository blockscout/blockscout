defmodule Explorer.Etherscan.Logs do
  @moduledoc """
  This module contains functions for working with logs, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query, only: [from: 2, where: 3, subquery: 1, order_by: 3]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{DenormalizationHelper, Log, Transaction}

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
    :first_topic,
    :second_topic,
    :third_topic,
    :fourth_topic,
    :index,
    :address_hash,
    :transaction_hash
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

    logs_query =
      Log
      |> where_topic_match(prepared_filter)
      |> where([log], log.address_hash == ^address_hash)
      |> where([log], log.block_number >= ^prepared_filter.from_block)
      |> where([log], log.block_number <= ^prepared_filter.to_block)
      |> page_logs(paging_options)

    if DenormalizationHelper.transactions_denormalization_finished?() do
      all_transaction_logs_query =
        from(log in subquery(logs_query),
          join: transaction in Transaction,
          on: log.transaction_hash == transaction.hash and log.block_hash == transaction.block_hash,
          where: transaction.block_consensus == true,
          select: map(log, ^@log_fields),
          select_merge: %{
            gas_price: transaction.gas_price,
            gas_used: transaction.gas_used,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            block_timestamp: transaction.block_timestamp,
            block_consensus: transaction.block_consensus
          },
          limit: 1000
        )

      all_transaction_logs_query
      |> Chain.wrapped_union_subquery()
      |> order_by([log], asc: log.block_number, asc: log.index)
      |> Repo.replica().all()
    else
      all_transaction_logs_query =
        from(log in subquery(logs_query),
          join: transaction in Transaction,
          on: log.transaction_hash == transaction.hash and log.block_hash == transaction.block_hash,
          inner_join: block in assoc(transaction, :block),
          where: block.consensus == true,
          select: map(log, ^@log_fields),
          select_merge: %{
            gas_price: transaction.gas_price,
            gas_used: transaction.gas_used,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            block_timestamp: block.timestamp,
            block_consensus: block.consensus
          },
          limit: 1000
        )

      all_transaction_logs_query
      |> Chain.wrapped_union_subquery()
      |> order_by([log], asc: log.block_number, asc: log.index)
      |> Repo.replica().all()
    end
  end

  # Since address_hash was not present, we know that a
  # topic filter has been applied, so we use a different
  # query that is optimized for a logs filter over an
  # address_hash
  def list_logs(filter, paging_options) do
    paging_options = if is_nil(paging_options), do: @default_paging_options, else: paging_options
    prepared_filter = Map.merge(@base_filter, filter)
    logs_query = where_topic_match(Log, prepared_filter)

    if DenormalizationHelper.transactions_denormalization_finished?() do
      block_transaction_query =
        from(transaction in Transaction,
          where: transaction.block_number >= ^prepared_filter.from_block,
          where: transaction.block_number <= ^prepared_filter.to_block,
          where: transaction.block_consensus == true,
          select: %{
            transaction_hash: transaction.hash,
            gas_price: transaction.gas_price,
            gas_used: transaction.gas_used,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            block_timestamp: transaction.block_timestamp,
            block_consensus: transaction.block_consensus
          }
        )

      query_with_block_transaction_data =
        from(log in logs_query,
          join: block_transaction_data in subquery(block_transaction_query),
          on:
            block_transaction_data.transaction_hash == log.transaction_hash and
              block_transaction_data.block_hash == log.block_hash,
          order_by: block_transaction_data.block_number,
          limit: 1000,
          select: block_transaction_data,
          select_merge: map(log, ^@log_fields)
        )

      query_with_block_transaction_data
      |> order_by([log], asc: log.index)
      |> page_logs(paging_options)
      |> Repo.replica().all()
    else
      block_transaction_query =
        from(transaction in Transaction,
          join: block in assoc(transaction, :block),
          where: block.number >= ^prepared_filter.from_block,
          where: block.number <= ^prepared_filter.to_block,
          where: block.consensus == true,
          select: %{
            transaction_hash: transaction.hash,
            gas_price: transaction.gas_price,
            gas_used: transaction.gas_used,
            transaction_index: transaction.index,
            block_hash: block.hash,
            block_number: block.number,
            block_timestamp: block.timestamp,
            block_consensus: block.consensus
          }
        )

      query_with_block_transaction_data =
        from(log in logs_query,
          join: block_transaction_data in subquery(block_transaction_query),
          on: block_transaction_data.transaction_hash == log.transaction_hash,
          order_by: block_transaction_data.block_number,
          limit: 1000,
          select: block_transaction_data,
          select_merge: map(log, ^@log_fields)
        )

      query_with_block_transaction_data
      |> order_by([log], asc: log.index)
      |> page_logs(paging_options)
      |> Repo.replica().all()
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

  defp where_topic_match(query, filter) do
    filter = sanitize_filter_topics(filter)

    case Enum.filter(@topics, &filter[&1]) do
      [] ->
        query

      [topic] ->
        where(query, [l], field(l, ^topic) in ^List.wrap(filter[topic]))

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
    where(query, [l], field(l, ^topic_a) == ^filter[topic_a] and field(l, ^topic_b) in ^List.wrap(filter[topic_b]))
  end

  defp where_multiple_topics_match(query, filter, topic_operation, "or") do
    {topic_a, topic_b} = @topic_operations[topic_operation]
    where(query, [l], field(l, ^topic_a) == ^filter[topic_a] or field(l, ^topic_b) in ^List.wrap(filter[topic_b]))
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
