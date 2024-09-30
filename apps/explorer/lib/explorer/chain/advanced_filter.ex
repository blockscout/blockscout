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

  @typep tx_types :: {:tx_types, [String.t()] | nil}
  @typep methods :: {:methods, [String.t()] | nil}
  @typep age :: {:age, [{:from, DateTime.t() | nil} | {:to, DateTime.t() | nil}] | nil}
  @typep from_address_hashes :: {:from_address_hashes, [Hash.Address.t()] | nil}
  @typep to_address_hashes :: {:to_address_hashes, [Hash.Address.t()] | nil}
  @typep address_relation :: {:address_relation, :or | :and | nil}
  @typep amount :: {:amount, [{:from, Decimal.t()} | {:to, Decimal.t()}] | nil}
  @typep token_contract_address_hashes ::
           {:token_contract_address_hashes, [{:include, [Hash.Address.t()]} | {:include, [Hash.Address.t()]}] | nil}
  @type options :: [
          tx_types()
          | methods()
          | age()
          | from_address_hashes()
          | to_address_hashes()
          | address_relation()
          | amount()
          | token_contract_address_hashes()
          | Chain.paging_options()
          | Chain.api?()
        ]

  @spec list(options()) :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options)

    tasks =
      options
      |> queries(paging_options)
      |> Enum.map(fn query -> Task.async(fn -> Chain.select_repo(options).all(query) end) end)

    tasks
    |> Task.yield_many(:timer.seconds(60))
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
    transaction_types = options[:tx_types]
    tokens_to_include = options[:token_contract_address_hashes][:include]

    transaction_types == ["COIN_TRANSFER"] or tokens_to_include == ["native"]
  end

  defp only_token_transfers?(options) do
    transaction_types = options[:tx_types]
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
      from_address: transaction.from_address,
      from_address_hash: transaction.from_address_hash,
      to_address: transaction.to_address,
      to_address_hash: transaction.to_address_hash,
      created_contract_address: transaction.created_contract_address,
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
      from_address: internal_transaction.from_address,
      from_address_hash: internal_transaction.from_address_hash,
      to_address: internal_transaction.to_address,
      to_address_hash: internal_transaction.to_address_hash,
      created_contract_address: internal_transaction.created_contract_address,
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
      from_address: token_transfer.from_address,
      from_address_hash: token_transfer.from_address_hash,
      to_address: token_transfer.to_address,
      to_address_hash: token_transfer.to_address_hash,
      created_contract_address: nil,
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
        preload: [
          :block,
          from_address: [:names, :smart_contract, :proxy_implementations],
          to_address: [:scam_badge, :names, :smart_contract, :proxy_implementations],
          created_contract_address: [:scam_badge, :names, :smart_contract, :proxy_implementations]
        ],
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
           transaction_index: tx_index
         }
       }) do
    dynamic_condition =
      dynamic(^page_block_number_dynamic(:transaction, block_number) or ^page_tx_index_dynamic(block_number, tx_index))

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
          from_address: [:names, :smart_contract, :proxy_implementations],
          to_address: [:scam_badge, :names, :smart_contract, :proxy_implementations],
          created_contract_address: [:scam_badge, :names, :smart_contract, :proxy_implementations],
          transaction: transaction
        ],
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
           transaction_index: tx_index,
           internal_transaction_index: nil
         }
       }) do
    case {block_number, tx_index} do
      {0, 0} ->
        query |> where(as(:transaction).block_number == ^block_number and as(:transaction).index == ^tx_index)

      {0, tx_index} ->
        query
        |> where(as(:transaction).block_number == ^block_number and as(:transaction).index <= ^tx_index)

      {block_number, 0} ->
        query |> where(as(:transaction).block_number < ^block_number)

      _ ->
        query
        |> where(
          as(:transaction).block_number < ^block_number or
            (as(:transaction).block_number == ^block_number and as(:transaction).index <= ^tx_index)
        )
    end
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: tx_index,
           internal_transaction_index: it_index
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:transaction, block_number) or ^page_tx_index_dynamic(block_number, tx_index) or
          ^page_it_index_dynamic(block_number, tx_index, it_index)
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
        order_by: [
          desc: token_transfer.block_number,
          desc: token_transfer.log_index
        ]
      )

    token_transfer_query
    |> apply_token_transfers_filters(options)
    |> page_token_transfers(paging_options)
    |> filter_token_transfers_by_amount(options[:amount][:from], options[:amount][:to])
    |> make_token_transfer_query_unnested()
    |> limit_query(paging_options)
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: tx_index,
           token_transfer_index: nil,
           internal_transaction_index: nil
         }
       }) do
    case {block_number, tx_index} do
      {0, 0} ->
        query |> where(as(:transaction).block_number == ^block_number and as(:transaction).index == ^tx_index)

      {0, tx_index} ->
        query
        |> where([token_transfer], token_transfer.block_number == ^block_number and as(:transaction).index < ^tx_index)

      {block_number, 0} ->
        query |> where([token_transfer], token_transfer.block_number < ^block_number)

      {block_number, tx_index} ->
        query
        |> where(
          [token_transfer],
          token_transfer.block_number < ^block_number or
            (token_transfer.block_number == ^block_number and as(:transaction).index <= ^tx_index)
        )
    end
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: tx_index,
           token_transfer_index: nil
         }
       }) do
    dynamic_condition =
      dynamic(
        ^page_block_number_dynamic(:token_transfer, block_number) or ^page_tx_index_dynamic(block_number, tx_index)
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

  defp page_tx_index_dynamic(block_number, tx_index) when tx_index > 0 do
    dynamic([transaction: tx], tx.block_number == ^block_number and tx.index < ^tx_index)
  end

  defp page_tx_index_dynamic(_, _) do
    dynamic(false)
  end

  defp page_it_index_dynamic(block_number, tx_index, it_index) when it_index > 0 do
    dynamic(
      [transaction: tx, internal_transaction: it],
      tx.block_number == ^block_number and tx.index == ^tx_index and
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

  defp apply_token_transfers_filters(query, options) do
    query
    |> filter_by_tx_type(options[:tx_types])
    |> filter_token_transfers_by_methods(options[:methods])
    |> filter_by_token(options[:token_contract_address_hashes][:include], :include)
    |> filter_by_token(options[:token_contract_address_hashes][:exclude], :exclude)
    |> apply_common_filters(options)
  end

  defp apply_transactions_filters(query, options) do
    query
    |> filter_transactions_by_amount(options[:amount][:from], options[:amount][:to])
    |> filter_transactions_by_methods(options[:methods])
    |> apply_common_filters(options)
  end

  defp apply_common_filters(query, options) do
    query
    |> only_collated_transactions()
    |> filter_by_timestamp(options[:age][:from], options[:age][:to])
    |> filter_by_addresses(options[:from_address_hashes], options[:to_address_hashes], options[:address_relation])
  end

  defp only_collated_transactions(query) do
    query |> where(not is_nil(as(:transaction).block_number) and not is_nil(as(:transaction).index))
  end

  defp filter_by_tx_type(query, [_ | _] = tx_types) do
    query |> where([token_transfer], token_transfer.token_type in ^tx_types)
  end

  defp filter_by_tx_type(query, _), do: query

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

  defp filter_by_timestamp(query, %DateTime{} = from, %DateTime{} = to) do
    query |> where(as(:transaction).block_timestamp >= ^from and as(:transaction).block_timestamp <= ^to)
  end

  defp filter_by_timestamp(query, %DateTime{} = from, _to) do
    query |> where(as(:transaction).block_timestamp >= ^from)
  end

  defp filter_by_timestamp(query, _from, %DateTime{} = to) do
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
    if has_named_binding?(query, :unnested_token_transfer) do
      query
    else
      from(token_transfer in subquery(query),
        as: :unnested_token_transfer,
        preload: [
          :transaction,
          :token,
          from_address: [:scam_badge, :names, :smart_contract, :proxy_implementations],
          to_address: [:scam_badge, :names, :smart_contract, :proxy_implementations]
        ],
        select_merge: %{
          token_ids: [token_transfer.token_id],
          amounts: [token_transfer.amount]
        }
      )
    end
  end

  defp filter_by_token(query, [_ | _] = token_contract_address_hashes, :include) do
    filtered = token_contract_address_hashes |> Enum.reject(&(&1 == "native"))
    query |> where([token_transfer], token_transfer.token_contract_address_hash in ^filtered)
  end

  defp filter_by_token(query, [_ | _] = token_contract_address_hashes, :exclude) do
    filtered = token_contract_address_hashes |> Enum.reject(&(&1 == "native"))
    query |> where([token_transfer], token_transfer.token_contract_address_hash not in ^filtered)
  end

  defp filter_by_token(query, _, _), do: query
end
