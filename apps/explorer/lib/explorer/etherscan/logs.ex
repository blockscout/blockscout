defmodule Explorer.Etherscan.Logs do
  @moduledoc """
  This module contains functions for working with logs, as they pertain to the
  `Explorer.Etherscan` context.

  """

  import Ecto.Query, only: [from: 2, where: 3, order_by: 3]

  alias Explorer.Repo
  alias Explorer.Chain.{Block, Log, Transaction}

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
    :transaction_hash,
    :type
  ]

  @transaction_fields [
    :gas_price,
    :gas_currency_hash,
    :gas_fee_recipient_hash,
    :gas_used,
    :gateway_fee,
    :block_number
  ]

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

  def list_logs(filter, paging_options) do
    paging_options = if is_nil(paging_options), do: @default_paging_options, else: paging_options
    prepared_filter = Map.merge(@base_filter, filter)

    logs_query = where_topic_match(Log, prepared_filter)

    query =
      from(t in Transaction,
        inner_join: log in ^logs_query,
        on: log.transaction_hash == t.hash,
        inner_join: block in Block,
        on: block.number == t.block_number,
        where: log.block_number >= ^prepared_filter.from_block,
        where: log.block_number <= ^prepared_filter.to_block,
        order_by: block.number,
        limit: 1_000,
        select: map(log, ^@log_fields),
        select_merge: map(t, ^@transaction_fields),
        select_merge: %{
          transaction_index: t.index,
          block_number: block.number,
          block_hash: block.hash,
          block_timestamp: block.timestamp,
          block_consensus: block.consensus
        }
      )

    query
    |> where_address_match(prepared_filter)
    |> where_consensus_match(prepared_filter)
    |> order_by([_, log], asc: log.index)
    |> page_logs(paging_options)
    |> Repo.replica().all()
  end

  defp where_address_match(query, %{address_hash: address_hash}) when not is_nil(address_hash) do
    where(query, [_, log], log.address_hash == ^address_hash)
  end

  defp where_address_match(query, _), do: query

  defp where_consensus_match(query, %{allow_non_consensus: allow_non_consensus}) when allow_non_consensus, do: query

  defp where_consensus_match(query, _) do
    where(query, [_, _, block], block.consensus == true)
  end

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

  defp page_logs(query, %{block_number: nil, transaction_index: nil, log_index: nil}), do: query

  defp page_logs(query, %{block_number: block_number, transaction_index: transaction_index, log_index: log_index}) do
    where(
      query,
      [transaction, log],
      log.index > ^log_index and log.block_number >= ^block_number and
        transaction.index >= ^transaction_index
    )
  end
end
