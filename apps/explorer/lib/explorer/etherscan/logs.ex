defmodule Explorer.Etherscan.Logs do
  @moduledoc """
  This module contains functions for working with logs, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query, only: [from: 2, where: 3, subquery: 1, order_by: 3, union: 2]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, InternalTransaction, Log, Transaction}

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
    topic2_3_opr: nil,
    limit: nil,
    order: nil,
    ignore_methods: nil
  }

  @log_fields [
    :data,
    :first_topic,
    :second_topic,
    :third_topic,
    :fourth_topic,
    :index,
    :address_hash,
    :transaction_hash,
    :type
  ]

  @default_paging_options %{block_number: nil, transaction_index: nil, log_index: nil}

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

    logs_query = where_topic_match(Log, prepared_filter)

    query_to_address_hash_wrapped =
      logs_query
      |> internal_transaction_query(:to_address_hash, prepared_filter, address_hash)
      |> Chain.wrapped_union_subquery()

    query_from_address_hash_wrapped =
      logs_query
      |> internal_transaction_query(:from_address_hash, prepared_filter, address_hash)
      |> Chain.wrapped_union_subquery()

    query_created_contract_address_hash_wrapped =
      logs_query
      |> internal_transaction_query(:created_contract_address_hash, prepared_filter, address_hash)
      |> Chain.wrapped_union_subquery()

    internal_transaction_log_query =
      query_to_address_hash_wrapped
      |> union(^query_from_address_hash_wrapped)
      |> union(^query_created_contract_address_hash_wrapped)

    all_transaction_logs_query =
      from(transaction in Transaction,
        join: log in ^logs_query,
        on: log.transaction_hash == transaction.hash,
        where: transaction.block_number >= ^prepared_filter.from_block,
        where: transaction.block_number <= ^prepared_filter.to_block,
        where:
          transaction.to_address_hash == ^address_hash or
            transaction.from_address_hash == ^address_hash or
            transaction.created_contract_address_hash == ^address_hash,
        select: map(log, ^@log_fields),
        select_merge: %{
          gas_price: transaction.gas_price,
          gas_used: transaction.gas_used,
          transaction_index: transaction.index,
          block_number: transaction.block_number
        },
        union: ^internal_transaction_log_query
      )

    query_with_blocks =
      from(log_transaction_data in subquery(all_transaction_logs_query),
        join: block in Block,
        on: block.number == log_transaction_data.block_number,
        where: log_transaction_data.address_hash == ^address_hash,
        limit: ^prepared_filter.limit,
        select_merge: %{
          transaction_index: log_transaction_data.transaction_index,
          block_hash: block.hash,
          block_number: block.number,
          block_timestamp: block.timestamp,
          block_consensus: block.consensus
        }
      )

    query_with_order =
      if Map.get(filter, :order) == "desc" do
        from([_, block] in query_with_blocks,
          order_by: [desc: block.number]
        )
      else
        from([_, block] in query_with_blocks,
          order_by: block.number
        )
      end

    query_with_ignore_methods =
      if Map.get(filter, :ignore_methods) != nil do
        from([log_transaction_data] in query_with_order,
          # where: log_transaction_data.first_topic in ^filter.ignore_methods
          where: log_transaction_data.first_topic not in ^filter.ignore_methods
        )
      else
        query_with_order
      end


    query_with_consensus =
      if Map.get(filter, :allow_non_consensus) do
        query_with_ignore_methods
      else
        from([_, block] in query_with_ignore_methods,
          where: block.consensus == true
        )
      end

    query_with_consensus
    |> page_logs(paging_options)
    |> Repo.replica().all()
  end

  # Since address_hash was not present, we know that a
  # topic filter has been applied, so we use a different
  # query that is optimized for a logs filter over an
  # address_hash
  def list_logs(filter, paging_options) do
    paging_options = if is_nil(paging_options), do: @default_paging_options, else: paging_options
    prepared_filter = Map.merge(@base_filter, filter)

    logs_query = where_topic_match(Log, prepared_filter)

    block_transaction_query =
      from(transaction in Transaction,
        join: block in assoc(transaction, :block),
        where: block.number >= ^prepared_filter.from_block,
        where: block.number <= ^prepared_filter.to_block,
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

    query_with_consensus =
      if Map.get(filter, :allow_non_consensus) do
        block_transaction_query
      else
        from([_, block] in block_transaction_query,
          where: block.consensus == true
        )
      end

    query_with_block_transaction_data =
      from(log in logs_query,
        join: block_transaction_data in subquery(query_with_consensus),
        on: block_transaction_data.transaction_hash == log.transaction_hash,
        limit: ^prepared_filter.limit,
        select: block_transaction_data,
        select_merge: map(log, ^@log_fields)
      )

    query_with_order =
      if Map.get(filter, :order) == "desc" do
        from([_, block_transaction_data] in query_with_block_transaction_data,
          order_by: [desc: block_transaction_data.block_number]
        )
      else
        from([_, block_transaction_data] in query_with_block_transaction_data,
          order_by: block_transaction_data.block_number
        )
      end


    query_with_order
    |> order_by([log], desc: log.block_number)
    |> page_logs(paging_options)
    |> Repo.replica().all()
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
    case Enum.filter(@topics, &filter[&1]) do
      [] ->
        query

      [topic] ->
        where(query, [l], field(l, ^topic) in ^List.wrap(filter[topic]))

      _ ->
        where_multiple_topics_match(query, filter)
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

  defp page_logs(query, %{block_number: nil, transaction_index: nil, log_index: nil}) do
    query
  end

  defp page_logs(query, %{block_number: block_number, transaction_index: transaction_index, log_index: log_index}) do
    from(
      data in query,
      where:
        data.index > ^log_index and data.block_number >= ^block_number and
          data.transaction_index >= ^transaction_index
    )
  end

  defp internal_transaction_query(logs_query, direction, prepared_filter, address_hash) do
    query =
      from(internal_transaction in InternalTransaction.where_nonpending_block(),
        join: transaction in assoc(internal_transaction, :transaction),
        join: log in ^logs_query,
        on: log.transaction_hash == internal_transaction.transaction_hash,
        where: internal_transaction.block_number >= ^prepared_filter.from_block,
        where: internal_transaction.block_number <= ^prepared_filter.to_block,
        select:
          merge(map(log, ^@log_fields), %{
            gas_price: transaction.gas_price,
            gas_used: transaction.gas_used,
            transaction_index: transaction.index,
            block_number: internal_transaction.block_number
          })
      )

    query
    |> InternalTransaction.where_address_fields_match(address_hash, direction)
  end
end
