defmodule Explorer.Etherscan do
  @moduledoc """
  The etherscan context.
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Explorer.Etherscan.Logs
  alias Explorer.{Repo, Chain}
  alias Explorer.Chain.{Hash, InternalTransaction, Transaction}

  @default_options %{
    order_by_direction: :asc,
    page_number: 1,
    page_size: 10_000,
    start_block: nil,
    end_block: nil
  }

  @doc """
  Returns the maximum allowed page size number.

  """
  @spec page_size_max :: pos_integer()
  def page_size_max do
    @default_options.page_size
  end

  @doc """
  Gets a list of transactions for a given `t:Explorer.Chain.Hash.Address.t/0`.

  """
  @spec list_transactions(Hash.Address.t()) :: [map()]
  def list_transactions(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash,
        options \\ @default_options
      ) do
    case Chain.max_block_number() do
      {:ok, max_block_number} ->
        merged_options = Map.merge(@default_options, options)
        list_transactions(address_hash, max_block_number, merged_options)

      _ ->
        []
    end
  end

  @internal_transaction_fields ~w(
    from_address_hash
    to_address_hash
    value
    created_contract_address_hash
    input
    type
    gas
    gas_used
    error
  )a

  @doc """
  Gets a list of internal transactions for a given transaction hash
  (`t:Explorer.Chain.Hash.Full.t/0`).

  Note that this function relies on `Explorer.Chain` to exclude/include
  internal transactions as follows:

    * exclude internal transactions of type call with no siblings in the
      transaction
    * include internal transactions of type create, reward, or suicide
      even when they are alone in the parent transaction

  """
  @spec list_internal_transactions(Hash.Full.t()) :: [map()]
  def list_internal_transactions(%Hash{byte_count: unquote(Hash.Full.byte_count())} = transaction_hash) do
    query =
      from(
        it in InternalTransaction,
        inner_join: t in assoc(it, :transaction),
        inner_join: b in assoc(t, :block),
        where: it.transaction_hash == ^transaction_hash,
        limit: 10_000,
        select:
          merge(map(it, ^@internal_transaction_fields), %{
            block_timestamp: b.timestamp,
            block_number: b.number
          })
      )

    query
    |> Chain.where_transaction_has_multiple_internal_transactions()
    |> Repo.all()
  end

  @doc """
  Gets a list of token transfers for a given `t:Explorer.Chain.Hash.Address.t/0`.

  """
  @spec list_token_transfers(Hash.Address.t(), Hash.Address.t() | nil, map()) :: [map()]
  def list_token_transfers(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash,
        contract_address_hash,
        options \\ @default_options
      ) do
    case Chain.max_block_number() do
      {:ok, max_block_number} ->
        merged_options = Map.merge(@default_options, options)
        list_token_transfers(address_hash, contract_address_hash, max_block_number, merged_options)

      _ ->
        []
    end
  end

  @transaction_fields ~w(
    block_hash
    block_number
    created_contract_address_hash
    cumulative_gas_used
    from_address_hash
    gas
    gas_price
    gas_used
    hash
    index
    input
    nonce
    status
    to_address_hash
    value
  )a

  defp list_transactions(address_hash, max_block_number, options) do
    query =
      from(
        t in Transaction,
        inner_join: b in assoc(t, :block),
        where: t.to_address_hash == ^address_hash,
        or_where: t.from_address_hash == ^address_hash,
        or_where: t.created_contract_address_hash == ^address_hash,
        order_by: [{^options.order_by_direction, t.block_number}],
        limit: ^options.page_size,
        offset: ^offset(options),
        select:
          merge(map(t, ^@transaction_fields), %{
            block_timestamp: b.timestamp,
            confirmations: fragment("? - ?", ^max_block_number, t.block_number)
          })
      )

    query
    |> where_start_block_match(options)
    |> where_end_block_match(options)
    |> Repo.all()
  end

  @token_transfer_fields ~w(
    token_contract_address_hash
    transaction_hash
    from_address_hash
    to_address_hash
    amount
  )a

  defp list_token_transfers(address_hash, contract_address_hash, max_block_number, options) do
    query =
      from(
        t in Transaction,
        inner_join: b in assoc(t, :block),
        inner_join: tt in assoc(t, :token_transfers),
        inner_join: tkn in assoc(tt, :token),
        where: tt.from_address_hash == ^address_hash,
        or_where: tt.to_address_hash == ^address_hash,
        order_by: [{^options.order_by_direction, t.block_number}],
        limit: ^options.page_size,
        offset: ^offset(options),
        select:
          merge(map(tt, ^@token_transfer_fields), %{
            transaction_nonce: t.nonce,
            transaction_index: t.index,
            transaction_gas: t.gas,
            transaction_gas_price: t.gas_price,
            transaction_gas_used: t.gas_used,
            transaction_cumulative_gas_used: t.cumulative_gas_used,
            transaction_input: t.input,
            block_hash: b.hash,
            block_number: b.number,
            block_timestamp: b.timestamp,
            confirmations: fragment("? - ?", ^max_block_number, t.block_number),
            token_name: tkn.name,
            token_symbol: tkn.symbol,
            token_decimals: tkn.decimals
          })
      )

    query
    |> where_start_block_match(options)
    |> where_end_block_match(options)
    |> where_contract_address_match(contract_address_hash)
    |> Repo.all()
  end

  defp where_start_block_match(query, %{start_block: nil}), do: query

  defp where_start_block_match(query, %{start_block: start_block}) do
    where(query, [t], t.block_number >= ^start_block)
  end

  defp where_end_block_match(query, %{end_block: nil}), do: query

  defp where_end_block_match(query, %{end_block: end_block}) do
    where(query, [t], t.block_number <= ^end_block)
  end

  defp where_contract_address_match(query, nil), do: query

  defp where_contract_address_match(query, contract_address_hash) do
    where(query, [_, _, tt], tt.token_contract_address_hash == ^contract_address_hash)
  end

  defp offset(options), do: (options.page_number - 1) * options.page_size

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
  def list_logs(filter), do: Logs.list_logs(filter)
end
