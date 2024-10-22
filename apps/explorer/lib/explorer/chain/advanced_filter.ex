defmodule Explorer.Chain.AdvancedFilter do
  @moduledoc """
  Models an advanced filter.
  """

  use Explorer.Schema

  import Ecto.Query

  alias Explorer.{Chain, Helper, PagingOptions}
  alias Explorer.Chain.{Address, Data, Hash, InternalTransaction, TokenTransfer, Transaction}

  @primary_key false
  typed_embedded_schema null: false do
    field(:hash, Hash.Full)
    field(:type, :string)
    field(:input, Data)
    field(:timestamp, :utc_datetime_usec)

    belongs_to(
      :from_address,
      Address,
      foreign_key: :from_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :to_address,
      Address,
      foreign_key: :to_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :created_contract_address,
      Address,
      foreign_key: :created_contract_address_hash,
      references: :hash,
      type: Hash.Address
    )

    field(:value, :decimal, null: true)

    has_one(:token_transfer, TokenTransfer, foreign_key: :transaction_hash, references: :hash, null: true)

    field(:fee, :decimal)

    field(:block_number, :integer)
    field(:transaction_index, :integer)
    field(:internal_transaction_index, :integer, null: true)
    field(:token_transfer_index, :integer, null: true)
    field(:token_transfer_batch_index, :integer, null: true)
  end

  @typep transaction_types :: {:transaction_types, [String.t()] | nil}
  @typep methods :: {:methods, [String.t()] | nil}
  @typep age :: {:age, [{:from, DateTime.t() | nil} | {:to, DateTime.t() | nil}] | nil}
  @typep from_address_hashes :: {:from_address_hashes, [Hash.Address.t()] | nil}
  @typep to_address_hashes :: {:to_address_hashes, [Hash.Address.t()] | nil}
  @typep address_relation :: {:address_relation, :or | :and | nil}
  @typep amount :: {:amount, [{:from, Decimal.t()} | {:to, Decimal.t()}] | nil}
  @typep token_contract_address_hashes ::
           {:token_contract_address_hashes, [{:include, [Hash.Address.t()]} | {:include, [Hash.Address.t()]}] | nil}
  @type options :: [
          transaction_types()
          | methods()
          | age()
          | from_address_hashes()
          | to_address_hashes()
          | address_relation()
          | amount()
          | token_contract_address_hashes()
          | Chain.paging_options()
          | Chain.api?()
          | {:timeout, timeout()}
        ]

  @spec list(options()) :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options)

    timeout = Keyword.get(options, :timeout, :timer.seconds(60))

    age = Keyword.get(options, :age)

    block_numbers_age =
      [
        from: age[:from] && Chain.timestamp_to_block_number(age[:from], :after, Keyword.get(options, :api?, false)),
        to: age[:to] && Chain.timestamp_to_block_number(age[:to], :before, Keyword.get(options, :api?, false))
      ]

    tasks =
      options
      |> Keyword.put(:block_numbers_age, block_numbers_age)
      |> queries(paging_options)
      |> Enum.map(fn query -> Task.async(fn -> Chain.select_repo(options).all(query, timeout: timeout) end) end)

    tasks
    |> Task.yield_many(timeout: timeout, on_timeout: :kill_task)
    |> Enum.flat_map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching advanced filters terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching advanced filters timed out."
      end
    end)
    |> Enum.map(&to_advanced_filter/1)
    |> Enum.sort(&sort_function/2)
    |> take_page_size(paging_options)
    |> Chain.select_repo(options).preload(
      token_transfer: [:token],
      from_address: [:names, :smart_contract, :proxy_implementations],
      to_address: [:names, :smart_contract, :proxy_implementations],
      created_contract_address: [:names, :smart_contract, :proxy_implementations]
    )
  end

  defp queries(options, paging_options) do
    cond do
      only_transactions?(options) ->
        [transactions_query(paging_options, options), internal_transactions_query(paging_options, options)]

      only_token_transfers?(options) ->
        [token_transfers_query(paging_options, options)]

      true ->
        [
          transactions_query(paging_options, options),
          internal_transactions_query(paging_options, options),
          token_transfers_query(paging_options, options)
        ]
    end
  end

  defp only_transactions?(options) do
    transaction_types = options[:transaction_types]
    tokens_to_include = options[:token_contract_address_hashes][:include]

    transaction_types == ["COIN_TRANSFER"] or tokens_to_include == ["native"]
  end

  defp only_token_transfers?(options) do
    transaction_types = options[:transaction_types]
    tokens_to_include = options[:token_contract_address_hashes][:include]
    tokens_to_exclude = options[:token_contract_address_hashes][:exclude]

    (is_list(transaction_types) and length(transaction_types) > 0 and "COIN_TRANSFER" not in transaction_types) or
      (is_list(tokens_to_include) and length(tokens_to_include) > 0 and "native" not in tokens_to_include) or
      (is_list(tokens_to_exclude) and "native" in tokens_to_exclude)
  end

  defp to_advanced_filter(%Transaction{} = transaction) do
    %__MODULE__{
      hash: transaction.hash,
      type: "coin_transfer",
      input: transaction.input,
      timestamp: transaction.block_timestamp,
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.to_address_hash,
      created_contract_address_hash: transaction.created_contract_address_hash,
      value: transaction.value.value,
      fee: transaction |> Transaction.fee(:wei) |> elem(1),
      block_number: transaction.block_number,
      transaction_index: transaction.index
    }
  end

  defp to_advanced_filter(%InternalTransaction{} = internal_transaction) do
    %__MODULE__{
      hash: internal_transaction.transaction.hash,
      type: "coin_transfer",
      input: internal_transaction.input,
      timestamp: internal_transaction.transaction.block_timestamp,
      from_address_hash: internal_transaction.from_address_hash,
      to_address_hash: internal_transaction.to_address_hash,
      created_contract_address_hash: internal_transaction.created_contract_address_hash,
      value: internal_transaction.value.value,
      fee:
        internal_transaction.transaction.gas_price && internal_transaction.gas_used &&
          Decimal.mult(internal_transaction.transaction.gas_price.value, internal_transaction.gas_used),
      block_number: internal_transaction.transaction.block_number,
      transaction_index: internal_transaction.transaction.index,
      internal_transaction_index: internal_transaction.index
    }
  end

  defp to_advanced_filter(%TokenTransfer{} = token_transfer) do
    %__MODULE__{
      hash: token_transfer.transaction.hash,
      type: token_transfer.token_type,
      input: token_transfer.transaction.input,
      timestamp: token_transfer.transaction.block_timestamp,
      from_address_hash: token_transfer.from_address_hash,
      to_address_hash: token_transfer.to_address_hash,
      created_contract_address_hash: nil,
      fee: token_transfer.transaction |> Transaction.fee(:wei) |> elem(1),
      token_transfer: %TokenTransfer{
        token_transfer
        | amounts: [token_transfer.amount],
          token_ids: token_transfer.token_id && [token_transfer.token_id]
      },
      block_number: token_transfer.block_number,
      transaction_index: token_transfer.transaction.index,
      token_transfer_index: token_transfer.log_index,
      token_transfer_batch_index: token_transfer.reverse_index_in_batch
    }
  end

  defp sort_function(a, b) do
    case {
      Helper.compare(a.block_number, b.block_number),
      Helper.compare(a.transaction_index, b.transaction_index),
      Helper.compare(a.token_transfer_index, b.token_transfer_index),
      Helper.compare(a.token_transfer_batch_index, b.token_transfer_batch_index),
      Helper.compare(a.internal_transaction_index, b.internal_transaction_index)
    } do
      {:lt, _, _, _, _} ->
        false

      {:eq, :lt, _, _, _} ->
        false

      {:eq, :eq, _, _, _} ->
        case {a.token_transfer_index, a.token_transfer_batch_index, a.internal_transaction_index,
              b.token_transfer_index, b.token_transfer_batch_index, b.internal_transaction_index} do
          {nil, _, nil, _, _, _} ->
            true

          {a_tt_index, a_tt_batch_index, nil, b_tt_index, b_tt_batch_index, _} when not is_nil(b_tt_index) ->
            {a_tt_index, a_tt_batch_index} > {b_tt_index, b_tt_batch_index}

          {nil, _, a_it_index, _, _, b_it_index} ->
            a_it_index > b_it_index

          {_, _, _, _, _, _} ->
            false
        end

      _ ->
        true
    end
  end

  defp take_page_size(list, %PagingOptions{page_size: page_size}) when is_integer(page_size) do
    Enum.take(list, page_size)
  end

  defp take_page_size(list, _), do: list

  defp transactions_query(paging_options, options) do
    query =
      from(transaction in Transaction,
        as: :transaction,
        where: transaction.block_consensus == true,
        order_by: [
          desc: transaction.block_number,
          desc: transaction.index
        ]
      )

    query
    |> page_transactions(paging_options)
    |> limit_query(paging_options)
    |> apply_transactions_filters(options)
  end

  defp page_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:transaction, block_number) or
          ^page_transaction_index_dynamic(block_number, transaction_index)
      )

    query |> where(^dynamic_condition)
  end

  defp page_transactions(query, _), do: query

  defp internal_transactions_query(paging_options, options) do
    query =
      from(internal_transaction in InternalTransaction,
        as: :internal_transaction,
        join: transaction in assoc(internal_transaction, :transaction),
        as: :transaction,
        preload: [
          transaction: transaction
        ],
        where: transaction.block_consensus == true,
        order_by: [
          desc: transaction.block_number,
          desc: transaction.index,
          desc: internal_transaction.index
        ]
      )

    query
    |> page_internal_transactions(paging_options)
    |> limit_query(paging_options)
    |> apply_transactions_filters(options)
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           internal_transaction_index: nil
         }
       }) do
    case {block_number, transaction_index} do
      {0, 0} ->
        query |> where(as(:transaction).block_number == ^block_number and as(:transaction).index == ^transaction_index)

      {0, transaction_index} ->
        query
        |> where(as(:transaction).block_number == ^block_number and as(:transaction).index <= ^transaction_index)

      {block_number, 0} ->
        query |> where(as(:transaction).block_number < ^block_number)

      _ ->
        query
        |> where(
          as(:transaction).block_number < ^block_number or
            (as(:transaction).block_number == ^block_number and as(:transaction).index <= ^transaction_index)
        )
    end
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           internal_transaction_index: it_index
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:transaction, block_number) or
          ^page_transaction_index_dynamic(block_number, transaction_index) or
          ^page_it_index_dynamic(block_number, transaction_index, it_index)
      )

    query
    |> where(^dynamic_condition)
  end

  defp page_internal_transactions(query, _), do: query

  defp token_transfers_query(paging_options, options) do
    token_transfer_query =
      from(token_transfer in TokenTransfer,
        as: :token_transfer,
        join: transaction in assoc(token_transfer, :transaction),
        as: :transaction,
        join: token in assoc(token_transfer, :token),
        as: :token,
        select: %TokenTransfer{
          token_transfer
          | token_id: fragment("UNNEST(?)", token_transfer.token_ids),
            amount:
              fragment("UNNEST(COALESCE(?, ARRAY[COALESCE(?, 1)]))", token_transfer.amounts, token_transfer.amount),
            reverse_index_in_batch:
              fragment("GENERATE_SERIES(COALESCE(ARRAY_LENGTH(?, 1), 1), 1, -1)", token_transfer.amounts),
            token_decimals: token.decimals
        },
        where: transaction.block_consensus == true,
        order_by: [
          desc: token_transfer.block_number,
          desc: token_transfer.log_index
        ]
      )

    token_transfer_query
    |> limit_query(paging_options)
    |> apply_token_transfers_filters_before_subquery(options)
    |> page_token_transfers(paging_options)
    |> apply_token_transfers_filters_after_subquery(options)
    |> make_token_transfer_query_unnested()
    |> limit_query(paging_options)
    |> preload([:transaction])
    |> select_merge([token_transfer], %{token_ids: [token_transfer.token_id], amounts: [token_transfer.amount]})
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           token_transfer_index: nil,
           internal_transaction_index: nil
         }
       }) do
    case {block_number, transaction_index} do
      {0, 0} ->
        query |> where(as(:transaction).block_number == ^block_number and as(:transaction).index == ^transaction_index)

      {0, transaction_index} ->
        query
        |> where(
          [token_transfer],
          token_transfer.block_number == ^block_number and as(:transaction).index < ^transaction_index
        )

      {block_number, 0} ->
        query |> where([token_transfer], token_transfer.block_number < ^block_number)

      {block_number, transaction_index} ->
        query
        |> where(
          [token_transfer],
          token_transfer.block_number < ^block_number or
            (token_transfer.block_number == ^block_number and as(:transaction).index <= ^transaction_index)
        )
    end
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: transaction_index,
           token_transfer_index: nil
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:token_transfer, block_number) or
          ^page_transaction_index_dynamic(block_number, transaction_index)
      )

    query |> where(^dynamic_condition)
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           token_transfer_index: tt_index,
           token_transfer_batch_index: tt_batch_index
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:token_transfer, block_number) or
          ^page_tt_index_dynamic(:token_transfer, block_number, tt_index, tt_batch_index)
      )

    paged_query = query |> where(^dynamic_condition)

    paged_query
    |> make_token_transfer_query_unnested()
    |> where(
      ^page_tt_batch_index_dynamic(
        block_number,
        tt_index,
        tt_batch_index
      )
    )
  end

  defp page_token_transfers(query, _), do: query

  defp page_block_number_dynamic(binding, block_number) when block_number > 0 do
    dynamic(as(^binding).block_number < ^block_number)
  end

  defp page_block_number_dynamic(_, _) do
    dynamic(false)
  end

  defp page_transaction_index_dynamic(block_number, transaction_index) when transaction_index > 0 do
    dynamic(
      [transaction: transaction],
      transaction.block_number == ^block_number and transaction.index < ^transaction_index
    )
  end

  defp page_transaction_index_dynamic(_, _) do
    dynamic(false)
  end

  defp page_it_index_dynamic(block_number, transaction_index, it_index) when it_index > 0 do
    dynamic(
      [transaction: transaction, internal_transaction: it],
      transaction.block_number == ^block_number and transaction.index == ^transaction_index and
        it.index < ^it_index
    )
  end

  defp page_it_index_dynamic(_, _, _) do
    dynamic(false)
  end

  defp page_tt_index_dynamic(binding, block_number, tt_index, tt_batch_index)
       when tt_index > 0 and tt_batch_index > 1 do
    dynamic(as(^binding).block_number == ^block_number and as(^binding).log_index <= ^tt_index)
  end

  defp page_tt_index_dynamic(binding, block_number, tt_index, _tt_batch_index) when tt_index > 0 do
    dynamic(as(^binding).block_number == ^block_number and as(^binding).log_index < ^tt_index)
  end

  defp page_tt_index_dynamic(_, _, _, _) do
    dynamic(false)
  end

  defp page_tt_batch_index_dynamic(block_number, tt_index, tt_batch_index) when tt_batch_index > 1 do
    dynamic(
      [unnested_token_transfer: tt],
      ^page_block_number_dynamic(:unnested_token_transfer, block_number) or
        ^page_tt_index_dynamic(
          :unnested_token_transfer,
          block_number,
          tt_index,
          0
        ) or
        (tt.block_number == ^block_number and tt.log_index == ^tt_index and tt.reverse_index_in_batch < ^tt_batch_index)
    )
  end

  defp page_tt_batch_index_dynamic(_, _, _) do
    dynamic(true)
  end

  defp limit_query(query, %PagingOptions{page_size: limit}) when is_integer(limit), do: limit(query, ^limit)

  defp limit_query(query, _), do: query

  defp apply_token_transfers_filters_before_subquery(query, options) do
    query
    |> filter_by_transaction_type(options[:transaction_types])
    |> filter_token_transfers_by_methods(options[:methods])
    |> filter_by_age(:token_transfer, options)
  end

  defp apply_token_transfers_filters_after_subquery(query, options) do
    query
    |> filter_token_transfers_by_amount(options[:amount][:from], options[:amount][:to])
    |> filter_token_transfers_by_addresses(
      options[:from_address_hashes],
      options[:to_address_hashes],
      options[:address_relation]
    )
    |> filter_by_token(options[:token_contract_address_hashes])
  end

  defp apply_transactions_filters(query, options) do
    query
    |> filter_transactions_by_amount(options[:amount][:from], options[:amount][:to])
    |> filter_transactions_by_methods(options[:methods])
    |> only_collated_transactions()
    |> filter_by_addresses(options[:from_address_hashes], options[:to_address_hashes], options[:address_relation])
    |> filter_by_age(:transaction, options)
  end

  defp only_collated_transactions(query) do
    query |> where(not is_nil(as(:transaction).block_number) and not is_nil(as(:transaction).index))
  end

  defp filter_by_transaction_type(query, [_ | _] = transaction_types) do
    query |> where([token_transfer], token_transfer.token_type in ^transaction_types)
  end

  defp filter_by_transaction_type(query, _), do: query

  defp filter_transactions_by_methods(query, [_ | _] = methods) do
    prepared_methods = prepare_methods(methods)

    query |> where([t], fragment("substring(? FOR 4)", t.input) in ^prepared_methods)
  end

  defp filter_transactions_by_methods(query, _), do: query

  defp filter_token_transfers_by_methods(query, [_ | _] = methods) do
    prepared_methods = prepare_methods(methods)

    query |> where(fragment("substring(? FOR 4)", as(:transaction).input) in ^prepared_methods)
  end

  defp filter_token_transfers_by_methods(query, _), do: query

  defp prepare_methods(methods) do
    methods
    |> Enum.flat_map(fn
      method ->
        case Data.cast(method) do
          {:ok, method} -> [method.bytes]
          _ -> []
        end
    end)
  end

  defp filter_by_age(query, entity, options) do
    query
    |> do_filter_by_age(options[:block_numbers_age][:from], options[:age][:from], entity, :from)
    |> do_filter_by_age(options[:block_numbers_age][:to], options[:age][:to], entity, :to)
  end

  defp do_filter_by_age(query, {:ok, block_number}, _timestamp, entity, direction) do
    filter_by_block_number(query, block_number, entity, direction)
  end

  defp do_filter_by_age(query, _block_number, timestamp, _entity, direction) do
    filter_by_timestamp(query, timestamp, direction)
  end

  defp filter_by_block_number(query, from, entity, :from) when not is_nil(from) do
    query |> where(as(^entity).block_number >= ^from)
  end

  defp filter_by_block_number(query, to, entity, :to) when not is_nil(to) do
    query |> where(as(^entity).block_number <= ^to)
  end

  defp filter_by_block_number(query, _, _, _), do: query

  defp filter_by_timestamp(query, %DateTime{} = from, :from) do
    query |> where(as(:transaction).block_timestamp >= ^from)
  end

  defp filter_by_timestamp(query, %DateTime{} = to, :to) do
    query |> where(as(:transaction).block_timestamp <= ^to)
  end

  defp filter_by_timestamp(query, _, _), do: query

  defp filter_by_addresses(query, from_addresses, to_addresses, relation) do
    to_address_dynamic = do_filter_by_addresses(:to_address_hash, to_addresses)

    from_address_dynamic = do_filter_by_addresses(:from_address_hash, from_addresses)

    final_condition =
      case {to_address_dynamic, from_address_dynamic} do
        {not_nil_to_address, not_nil_from_address} when nil not in [not_nil_to_address, not_nil_from_address] ->
          combine_filter_by_addresses(not_nil_to_address, not_nil_from_address, relation)

        _ ->
          to_address_dynamic || from_address_dynamic
      end

    case final_condition do
      not_nil when not is_nil(not_nil) -> query |> where(^not_nil)
      _ -> query
    end
  end

  defp do_filter_by_addresses(field, addresses) do
    to_include_dynamic = do_filter_by_addresses_inclusion(field, addresses && Keyword.get(addresses, :include))
    to_exclude_dynamic = do_filter_by_addresses_exclusion(field, addresses && Keyword.get(addresses, :exclude))

    case {to_include_dynamic, to_exclude_dynamic} do
      {not_nil_include, not_nil_exclude} when nil not in [not_nil_include, not_nil_exclude] ->
        dynamic([t], ^not_nil_include and ^not_nil_exclude)

      _ ->
        to_include_dynamic || to_exclude_dynamic
    end
  end

  defp do_filter_by_addresses_inclusion(field, [_ | _] = addresses) do
    dynamic([t], field(t, ^field) in ^addresses)
  end

  defp do_filter_by_addresses_inclusion(_, _), do: nil

  defp do_filter_by_addresses_exclusion(field, [_ | _] = addresses) do
    dynamic([t], field(t, ^field) not in ^addresses)
  end

  defp do_filter_by_addresses_exclusion(_, _), do: nil

  defp combine_filter_by_addresses(from_addresses_dynamic, to_addresses_dynamic, :or) do
    dynamic([t], ^from_addresses_dynamic or ^to_addresses_dynamic)
  end

  defp combine_filter_by_addresses(from_addresses_dynamic, to_addresses_dynamic, _) do
    dynamic([t], ^from_addresses_dynamic and ^to_addresses_dynamic)
  end

  defp filter_token_transfers_by_addresses(query, from_addresses, to_addresses, relation) do
    case {process_address_inclusion(from_addresses), process_address_inclusion(to_addresses)} do
      {nil, nil} -> query
      {from, nil} -> do_filter_token_transfers_by_address(query, from, :from_address_hash)
      {nil, to} -> do_filter_token_transfers_by_address(query, to, :to_address_hash)
      {from, to} -> do_filter_token_transfers_by_both_addresses(query, from, to, relation)
    end
  end

  defp do_filter_token_transfers_by_address(query, {:include, addresses}, field) do
    queries =
      addresses
      |> Enum.map(fn address -> query |> where([t], field(t, ^field) == ^address) end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    from(token_transfer in subquery(queries),
      as: :unnested_token_transfer,
      order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
    )
  end

  defp do_filter_token_transfers_by_address(query, {:exclude, addresses}, field) do
    query |> where([t], field(t, ^field) not in ^addresses)
  end

  defp do_filter_token_transfers_by_both_addresses(query, {:include, from}, {:include, to}, relation) do
    from_queries =
      from
      |> Enum.map(fn from_address -> query |> where([t], t.from_address_hash == ^from_address) end)

    to_queries =
      to
      |> Enum.map(fn to_address -> query |> where([t], t.to_address_hash == ^to_address) end)

    case relation do
      :and ->
        united_from_queries =
          from_queries |> map_first(&subquery/1) |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

        united_to_queries =
          to_queries |> map_first(&subquery/1) |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

        from(token_transfer in subquery(intersect_all(united_from_queries, ^united_to_queries)),
          as: :unnested_token_transfer,
          order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
        )

      _ ->
        union_query =
          from_queries
          |> Kernel.++(to_queries)
          |> map_first(&subquery/1)
          |> Enum.reduce(fn query, acc -> union(acc, ^query) end)

        from(token_transfer in subquery(union_query),
          as: :unnested_token_transfer,
          order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
        )
    end
  end

  defp do_filter_token_transfers_by_both_addresses(query, {:include, from}, {:exclude, to}, :and) do
    from_queries =
      from
      |> Enum.map(fn from_address ->
        query |> where([t], t.from_address_hash == ^from_address and t.to_address_hash not in ^to)
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    from(token_transfer in subquery(from_queries),
      as: :unnested_token_transfer,
      order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
    )
  end

  defp do_filter_token_transfers_by_both_addresses(query, {:include, from}, {:exclude, to}, _relation) do
    from_queries =
      from
      |> Enum.map(fn from_address ->
        query |> where([t], t.from_address_hash == ^from_address or t.to_address_hash not in ^to)
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    from(token_transfer in subquery(from_queries),
      as: :unnested_token_transfer,
      order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
    )
  end

  defp do_filter_token_transfers_by_both_addresses(query, {:exclude, from}, {:include, to}, :and) do
    to_queries =
      to
      |> Enum.map(fn to_address ->
        query |> where([t], t.to_address_hash == ^to_address and t.from_address_hash not in ^from)
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    from(token_transfer in subquery(to_queries),
      as: :unnested_token_transfer,
      order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
    )
  end

  defp do_filter_token_transfers_by_both_addresses(query, {:exclude, from}, {:include, to}, _relation) do
    to_queries =
      to
      |> Enum.map(fn to_address ->
        query |> where([t], t.to_address_hash == ^to_address or t.from_address_hash not in ^from)
      end)
      |> map_first(&subquery/1)
      |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

    from(token_transfer in subquery(to_queries),
      as: :unnested_token_transfer,
      order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
    )
  end

  defp do_filter_token_transfers_by_both_addresses(query, {:exclude, from}, {:exclude, to}, :and) do
    query |> where([t], t.from_address_hash not in ^from and t.to_address_hash not in ^to)
  end

  defp do_filter_token_transfers_by_both_addresses(query, {:exclude, from}, {:exclude, to}, _relation) do
    query |> where([t], t.from_address_hash not in ^from or t.to_address_hash not in ^to)
  end

  @eth_decimals 1000_000_000_000_000_000

  defp filter_transactions_by_amount(query, from, to) when not is_nil(from) and not is_nil(to) and from < to do
    query |> where([t], t.value / @eth_decimals >= ^from and t.value / @eth_decimals <= ^to)
  end

  defp filter_transactions_by_amount(query, _from, to) when not is_nil(to) do
    query |> where([t], t.value / @eth_decimals <= ^to)
  end

  defp filter_transactions_by_amount(query, from, _to) when not is_nil(from) do
    query |> where([t], t.value / @eth_decimals >= ^from)
  end

  defp filter_transactions_by_amount(query, _, _), do: query

  defp filter_token_transfers_by_amount(query, from, to) when not is_nil(from) and not is_nil(to) and from < to do
    unnested_query = make_token_transfer_query_unnested(query)

    unnested_query
    |> where(
      [unnested_token_transfer: tt],
      tt.amount / fragment("10 ^ COALESCE(?, 0)", tt.token_decimals) >= ^from and
        tt.amount / fragment("10 ^ COALESCE(?, 0)", tt.token_decimals) <= ^to
    )
  end

  defp filter_token_transfers_by_amount(query, _from, to) when not is_nil(to) do
    unnested_query = make_token_transfer_query_unnested(query)

    unnested_query
    |> where(
      [unnested_token_transfer: tt],
      tt.amount / fragment("10 ^ COALESCE(?, 0)", tt.token_decimals) <= ^to
    )
  end

  defp filter_token_transfers_by_amount(query, from, _to) when not is_nil(from) do
    unnested_query = make_token_transfer_query_unnested(query)

    unnested_query
    |> where(
      [unnested_token_transfer: tt],
      tt.amount / fragment("10 ^ COALESCE(?, 0)", tt.token_decimals) >= ^from
    )
  end

  defp filter_token_transfers_by_amount(query, _, _), do: query

  defp make_token_transfer_query_unnested(query) do
    with_named_binding(query, :unnested_token_transfer, fn query, binding ->
      from(token_transfer in subquery(query),
        as: ^binding
      )
    end)
  end

  defp filter_by_token(query, token_contract_address_hashes) when is_list(token_contract_address_hashes) do
    case process_address_inclusion(token_contract_address_hashes) do
      {:include, token_contract_address_hashes} ->
        to_include_filtered = token_contract_address_hashes |> Enum.reject(&(&1 == "native"))

        queries =
          to_include_filtered
          |> Enum.map(fn address ->
            query |> where([t], t.token_contract_address_hash == ^address)
          end)
          |> map_first(&subquery/1)
          |> Enum.reduce(fn query, acc -> union_all(acc, ^query) end)

        from(token_transfer in subquery(queries),
          as: :unnested_token_transfer,
          order_by: [desc: token_transfer.block_number, desc: token_transfer.log_index]
        )

      {:exclude, token_contract_address_hashes} ->
        to_exclude_filtered = token_contract_address_hashes |> Enum.reject(&(&1 == "native"))

        from(token_transfer in query,
          left_join: to_exclude in fragment("UNNEST(?)", type(^to_exclude_filtered, {:array, Hash.Address})),
          on: token_transfer.token_contract_address_hash == to_exclude,
          where: is_nil(to_exclude)
        )

      _ ->
        query
    end
  end

  defp filter_by_token(query, _), do: query

  defp process_address_inclusion(addresses) when is_list(addresses) do
    case {Keyword.get(addresses, :include, []), Keyword.get(addresses, :exclude, [])} do
      {to_include, to_exclude} when to_include in [nil, []] and to_exclude in [nil, []] ->
        nil

      {to_include, to_exclude} when to_include in [nil, []] and is_list(to_exclude) ->
        {:exclude, to_exclude}

      {to_include, to_exclude} when is_list(to_include) ->
        {:include, to_include -- (to_exclude || [])}
    end
  end

  defp process_address_inclusion(_), do: nil

  defp map_first([h | t], f), do: [f.(h) | t]
  defp map_first([], _f), do: []
end
