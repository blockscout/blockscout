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

    field(:value, :decimal, null: true)

    has_one(:token_transfer, TokenTransfer, foreign_key: :transaction_hash, references: :hash, null: true)

    field(:block_number, :integer)
    field(:transaction_index, :integer)
    field(:internal_transaction_index, :integer)
    field(:token_transfer_index, :integer)
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
    transaction_types = options[:tx_types]
    tokens_to_include = options[:token_contract_address_hashes][:include]

    cond do
      transaction_types == ["COIN_TRANSFER"] ->
        [transactions_query(paging_options, options), internal_transactions_query(paging_options, options)]

      (is_list(transaction_types) and length(transaction_types) > 0 and "COIN_TRANSFER" not in transaction_types) or
          (is_list(tokens_to_include) and length(tokens_to_include) > 0) ->
        [token_transfers_query(paging_options, options)]

      true ->
        [
          transactions_query(paging_options, options),
          internal_transactions_query(paging_options, options),
          token_transfers_query(paging_options, options)
        ]
    end
  end

  defp to_advanced_filter(%Transaction{} = transaction) do
    %__MODULE__{
      hash: transaction.hash,
      type: "coin_transfer",
      input: transaction.input,
      timestamp: transaction.block_timestamp,
      from_address: transaction.from_address,
      to_address: transaction.to_address,
      value: transaction.value,
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
      to_address: internal_transaction.to_address,
      value: internal_transaction.value,
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
      to_address: token_transfer.to_address,
      token_transfer: token_transfer,
      block_number: token_transfer.block_number,
      transaction_index: token_transfer.transaction.index,
      token_transfer_index: token_transfer.log_index
    }
  end

  defp sort_function(a, b) do
    case {
      Helper.compare(a.block_number, b.block_number),
      Helper.compare(a.transaction_index, b.transaction_index),
      Helper.compare(a.token_transfer_index, b.token_transfer_index),
      Helper.compare(a.internal_transaction_index, b.internal_transaction_index)
    } do
      {:lt, _, _, _} ->
        false

      {:eq, :lt, _, _} ->
        false

      {:eq, :eq, _, _} ->
        case {a.token_transfer_index, a.internal_transaction_index, b.token_transfer_index,
              b.internal_transaction_index} do
          {nil, nil, _, _} -> true
          {a_tt_index, nil, b_tt_index, _} when not is_nil(b_tt_index) -> a_tt_index > b_tt_index
          {nil, a_it_index, _, b_it_index} -> a_it_index > b_it_index
          {_, _, _, _} -> false
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
        join: from_address in assoc(transaction, :from_address),
        join: to_address in assoc(transaction, :to_address),
        preload: [from_address: from_address, to_address: to_address],
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
    query
    |> where(
      [transaction],
      transaction.block_number < ^block_number or
        (transaction.block_number == ^block_number and transaction.index < ^tx_index)
    )
  end

  defp page_transactions(query, _), do: query

  defp internal_transactions_query(paging_options, options) do
    query =
      from(internal_transaction in InternalTransaction,
        join: transaction in assoc(internal_transaction, :transaction),
        as: :transaction,
        join: from_address in assoc(internal_transaction, :from_address),
        join: to_address in assoc(internal_transaction, :to_address),
        preload: [transaction: transaction, from_address: from_address, to_address: to_address],
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
    query
    |> where(
      as(:transaction).block_number < ^block_number or
        (as(:transaction).block_number == ^block_number and as(:transaction).index < ^tx_index) or
        (as(:transaction).block_number == ^block_number and as(:transaction).index == ^tx_index)
    )
  end

  defp page_internal_transactions(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: tx_index,
           internal_transaction_index: it_index
         }
       }) do
    query
    |> where(
      [internal_transaction],
      as(:transaction).block_number < ^block_number or
        (as(:transaction).block_number == ^block_number and as(:transaction).index < ^tx_index) or
        (as(:transaction).block_number == ^block_number and as(:transaction).index == ^tx_index and
           internal_transaction.index < ^it_index)
    )
  end

  defp page_internal_transactions(query, _), do: query

  defp token_transfers_query(paging_options, options) do
    query =
      from(token_transfer in TokenTransfer,
        join: transaction in assoc(token_transfer, :transaction),
        as: :transaction,
        join: token in assoc(token_transfer, :token),
        as: :token,
        join: from_address in assoc(token_transfer, :from_address),
        join: to_address in assoc(token_transfer, :to_address),
        preload: [transaction: transaction, token: token, from_address: from_address, to_address: to_address],
        order_by: [
          desc: token_transfer.block_number,
          desc: token_transfer.log_index
        ]
      )

    query
    |> page_token_transfers(paging_options)
    |> limit_query(paging_options)
    |> apply_token_transfers_filters(options)
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: tx_index,
           token_transfer_index: nil,
           internal_transaction_index: nil
         }
       }) do
    query
    |> where(
      [token_transfer],
      token_transfer.block_number < ^block_number or
        (token_transfer.block_number == ^block_number and as(:transaction).index < ^tx_index) or
        (token_transfer.block_number == ^block_number and as(:transaction).index == ^tx_index)
    )
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: tx_index,
           token_transfer_index: nil
         }
       }) do
    query
    |> where(
      [token_transfer],
      token_transfer.block_number < ^block_number or
        (token_transfer.block_number == ^block_number and as(:transaction).index < ^tx_index)
    )
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           token_transfer_index: tt_index
         }
       }) do
    query
    |> where(
      [token_transfer],
      token_transfer.block_number < ^block_number or
        (token_transfer.block_number == ^block_number and token_transfer.log_index < ^tt_index)
    )
  end

  defp page_token_transfers(query, _), do: query

  defp limit_query(query, %PagingOptions{page_size: limit}) when is_integer(limit), do: limit(query, ^limit)

  defp limit_query(query, _), do: query

  defp apply_token_transfers_filters(query, options) do
    query
    |> filter_by_tx_type(options[:tx_types])
    |> filter_token_transfers_by_methods(options[:methods])
    |> filter_by_token(options[:token_contract_address_hashes][:include], :include)
    |> filter_by_token(options[:token_contract_address_hashes][:exclude], :exclude)
    |> filter_token_transfers_by_amount(options[:amount][:from], options[:amount][:to])
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
    |> Enum.map(fn
      method ->
        case Data.cast(method) do
          {:ok, method} -> method.bytes
          _ -> nil
        end
    end)
    |> Enum.reject(&is_nil(&1))
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

  defp filter_by_addresses(query, [_ | _] = from_addresses, [_ | _] = to_addresses, :and) do
    query |> where([t], t.from_address_hash in ^from_addresses and t.to_address_hash in ^to_addresses)
  end

  defp filter_by_addresses(query, [_ | _] = from_addresses, [_ | _] = to_addresses, :or) do
    query |> where([t], t.from_address_hash in ^from_addresses or t.to_address_hash in ^to_addresses)
  end

  defp filter_by_addresses(query, [_ | _] = from_addresses, _, _) do
    query |> where([t], t.from_address_hash in ^from_addresses)
  end

  defp filter_by_addresses(query, _, [_ | _] = to_addresses, _) do
    query |> where([t], t.to_address_hash in ^to_addresses)
  end

  defp filter_by_addresses(query, _, _, _), do: query

  @eth_decimals 1000_000_000_000_000_000

  defp filter_transactions_by_amount(query, from, to) when not is_nil(from) and not is_nil(to) do
    query |> where([t], t.value / @eth_decimals >= ^from and t.value / @eth_decimals <= ^to)
  end

  defp filter_transactions_by_amount(query, _, _), do: query

  defp filter_token_transfers_by_amount(query, from, to) when not is_nil(from) and not is_nil(to) do
    query
    |> where(
      [token_transfer],
      token_transfer.amount / fragment("10 ^ ?", as(:token).decimals) >= ^from and
        token_transfer.amount / fragment("10 ^ ?", as(:token).decimals) <= ^to
    )
  end

  defp filter_token_transfers_by_amount(query, _, _), do: query

  defp filter_by_token(query, [_ | _] = token_contract_address_hashes, :include) do
    query |> where([token_transfer], token_transfer.token_contract_address_hash in ^token_contract_address_hashes)
  end

  defp filter_by_token(query, [_ | _] = token_contract_address_hashes, :exclude) do
    query |> where([token_transfer], token_transfer.token_contract_address_hash not in ^token_contract_address_hashes)
  end

  defp filter_by_token(query, _, _), do: query
end
