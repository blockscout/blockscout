defmodule Explorer.Chain.AdvancedFilter do
  @moduledoc """
  Models an advanced filter.
  """

  use Explorer.Schema

  import Ecto.Query

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Address, Data, Hash, InternalTransaction, Token, TokenTransfer, Transaction, Wei}

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

    field(:token_contract_address_hash, Hash.Address, null: true)
    has_one(:token, Token, foreign_key: :contract_address_hash, references: :token_contract_address_hash, null: true)

    has_one(:token_transfer, TokenTransfer, foreign_key: :transaction_hash, references: :hash, null: true)

    field(:block_number, :integer)
    field(:transaction_index, :integer)
    field(:internal_transaction_index, :integer)
    field(:token_transfer_index, :integer)
  end

  token_fields_count = :fields |> Token.__schema__() |> Enum.count()
  @null_token 1..token_fields_count |> Map.new(fn i -> {String.to_atom("#{i}"), nil} end)

  token_transfer_fields_count = :fields |> TokenTransfer.__schema__() |> Enum.count()

  @null_token_transfer 1..token_transfer_fields_count
                       |> Map.new(fn i -> {String.to_atom("#{i}"), nil} end)

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
    base_query = base_query(options, paging_options)

    base_query
    |> order_by(
      desc: fragment("block_number_pagination"),
      desc: fragment("transaction_index_pagination"),
      desc: fragment("token_transfer_index_pagination"),
      desc: fragment("internal_transaction_index_pagination")
    )
    |> limit_query(paging_options)
    |> Chain.select_repo(options).all()
  end

  defp base_query(options, paging_options) do
    transaction_types = options[:tx_types]
    tokens_to_include = options[:token_contract_address_hashes][:include]

    cond do
      transaction_types == ["coin_transfer"] ->
        paging_options
        |> transactions_query(options)
        |> union_all(^internal_transactions_query(paging_options, options))

      (is_list(transaction_types) and "coin_transfer" not in transaction_types) or
          (is_list(tokens_to_include) and length(tokens_to_include) > 0) ->
        token_transfers_query(paging_options, options)

      true ->
        paging_options
        |> token_transfers_query(options)
        |> union_all(^transactions_query(paging_options, options))
        |> union_all(^internal_transactions_query(paging_options, options))
    end
  end

  defp limit_query(query, %PagingOptions{page_size: limit}) when is_integer(limit), do: limit(query, ^limit)

  defp limit_query(query, _), do: query

  defp transactions_query(paging_options, options) do
    query =
      from(t in Transaction,
        as: :transaction,
        join: from_address in assoc(t, :from_address),
        join: to_address in assoc(t, :to_address),
        select: %__MODULE__{
          token_transfer: @null_token_transfer,
          hash: t.hash,
          type: "coin_transfer",
          input: t.input,
          timestamp: t.block_timestamp,
          from_address: from_address,
          to_address: to_address,
          value: t.value,
          token: @null_token,
          block_number: fragment("? as block_number_pagination", t.block_number),
          transaction_index: fragment("? as transaction_index_pagination", t.index),
          internal_transaction_index: fragment("null :: integer as internal_transaction_index_pagination"),
          token_transfer_index: fragment("null :: integer as token_transfer_index_pagination")
        }
      )

    query
    |> page_transactions(paging_options)
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
      as(:transaction).block_number < ^block_number or
        (as(:transaction).block_number == ^block_number and as(:transaction).index < ^tx_index)
    )
  end

  defp page_transactions(query, _), do: query

  defp internal_transactions_query(paging_options, options) do
    query =
      from(it in InternalTransaction,
        as: :internal_transaction,
        join: t in assoc(it, :transaction),
        as: :transaction,
        join: from_address in assoc(it, :from_address),
        join: to_address in assoc(it, :to_address),
        select: %__MODULE__{
          token_transfer: @null_token_transfer,
          hash: t.hash,
          type: "coin_transfer",
          input: it.input,
          timestamp: t.block_timestamp,
          from_address: from_address,
          to_address: to_address,
          value: it.value,
          token: @null_token,
          block_number: fragment("? as block_number_pagination", t.block_number),
          transaction_index: fragment("? as transaction_index_pagination", t.index),
          internal_transaction_index: fragment("? :: integer as internal_transaction_index_pagination", it.index),
          token_transfer_index: fragment("null :: integer as token_transfer_index_pagination")
        }
      )

    query
    |> page_internal_transactions(paging_options)
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
      as(:transaction).block_number < ^block_number or
        (as(:transaction).block_number == ^block_number and as(:transaction).index < ^tx_index) or
        (as(:transaction).block_number == ^block_number and as(:transaction).index == ^tx_index and
           as(:internal_transaction).index < ^it_index)
    )
  end

  defp page_internal_transactions(query, _), do: query

  defp token_transfers_query(paging_options, options) do
    query =
      from(tt in TokenTransfer,
        as: :token_transfer,
        join: tx in assoc(tt, :transaction),
        as: :transaction,
        join: t in assoc(tt, :token),
        as: :token,
        join: from_address in assoc(tt, :from_address),
        join: to_address in assoc(tt, :to_address),
        select: %__MODULE__{
          hash: tx.hash,
          type: tt.token_type,
          input: tx.input,
          timestamp: tx.block_timestamp,
          from_address: from_address,
          to_address: to_address,
          value: type(^nil, Wei),
          token: t,
          token_transfer: tt,
          block_number: fragment("? as block_number_pagination", tt.block_number),
          transaction_index: fragment("? as transaction_index_pagination", tx.index),
          internal_transaction_index: fragment("null :: integer as internal_transaction_index_pagination"),
          token_transfer_index: fragment("? as token_transfer_index_pagination", tt.log_index)
        }
      )

    query
    |> page_token_transfers(paging_options)
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
      as(:token_transfer).block_number < ^block_number or
        (as(:token_transfer).block_number == ^block_number and as(:transaction).index < ^tx_index) or
        (as(:token_transfer).block_number == ^block_number and as(:transaction).index == ^tx_index)
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
      as(:token_transfer).block_number < ^block_number or
        (as(:token_transfer).block_number == ^block_number and as(:transaction).index < ^tx_index)
    )
  end

  defp page_token_transfers(query, %PagingOptions{
         key: %{
           block_number: block_number,
           transaction_index: tx_index,
           token_transfer_index: tt_index
         }
       }) do
    query
    |> where(
      as(:token_transfer).block_number < ^block_number or
        (as(:token_transfer).block_number == ^block_number and as(:transaction).index < ^tx_index) or
        (as(:token_transfer).block_number == ^block_number and as(:transaction).index == ^tx_index and
           as(:token_transfer).log_index < ^tt_index)
    )
  end

  defp page_token_transfers(query, _), do: query

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
    query |> where(as(:token_transfer).token_type in ^tx_types)
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

  defp filter_by_timestamp(query, _, _), do: query

  defp filter_by_addresses(query, [_ | _] = from_addresses, [_ | _] = to_addresses, :and) do
    query |> where([af], af.from_address_hash in ^from_addresses and af.to_address_hash in ^to_addresses)
  end

  defp filter_by_addresses(query, [_ | _] = from_addresses, [_ | _] = to_addresses, :or) do
    query |> where([af], af.from_address_hash in ^from_addresses or af.to_address_hash in ^to_addresses)
  end

  defp filter_by_addresses(query, [_ | _] = from_addresses, _, _) do
    query |> where([af], af.from_address_hash in ^from_addresses)
  end

  defp filter_by_addresses(query, _, [_ | _] = to_addresses, _) do
    query |> where([af], af.to_address_hash in ^to_addresses)
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
      [af],
      af.amount / fragment("10 ^ ?", as(:token).decimals) >= ^from and
        af.amount / fragment("10 ^ ?", as(:token).decimals) <= ^to
    )
  end

  defp filter_token_transfers_by_amount(query, _, _), do: query

  defp filter_by_token(query, [_ | _] = token_contract_address_hashes, :include) do
    query |> where([af], af.token_contract_address_hash in ^token_contract_address_hashes)
  end

  defp filter_by_token(query, [_ | _] = token_contract_address_hashes, :exclude) do
    query |> where([af], af.token_contract_address_hash not in ^token_contract_address_hashes)
  end

  defp filter_by_token(query, _, _), do: query
end
