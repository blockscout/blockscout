defmodule Explorer.Etherscan do
  @moduledoc """
  The etherscan context.
  """

  import Ecto.Query, only: [from: 2, where: 3, or_where: 3, union: 2, subquery: 1, order_by: 3]

  alias Explorer.Etherscan.Logs
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Chain.{Block, Hash, InternalTransaction, TokenTransfer, Transaction}

  @default_options %{
    order_by_direction: :desc,
    page_number: 1,
    page_size: 10_000,
    start_block: nil,
    end_block: nil,
    start_timestamp: nil,
    end_timestamp: nil
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

  If `filter_by: "to"` is given as an option, address matching is only done
  against the `to_address_hash` column. If not, `to_address_hash`,
  `from_address_hash`, and `created_contract_address_hash` are all considered.

  """
  @spec list_transactions(Hash.Address.t()) :: [map()]
  def list_transactions(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash,
        options \\ @default_options
      ) do
    case Chain.max_consensus_block_number() do
      {:ok, max_block_number} ->
        merged_options = Map.merge(@default_options, options)
        list_transactions(address_hash, max_block_number, merged_options)

      _ ->
        []
    end
  end

  @doc """
  Gets a list of pending transactions for a given `t:Explorer.Chain.Hash.Address.t/0`.

  If `filter_by: `to_address_hash`,
  `from_address_hash`, and `created_contract_address_hash`.

  """
  @spec list_pending_transactions(Hash.Address.t()) :: [map()]
  def list_pending_transactions(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash,
        options \\ @default_options
      ) do
    merged_options = Map.merge(@default_options, options)
    list_pending_transactions_query(address_hash, merged_options)
  end

  @internal_transaction_fields ~w(
    from_address_hash
    to_address_hash
    transaction_hash
    index
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
    * include internal transactions of type create, reward, or selfdestruct
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
    |> InternalTransaction.where_is_different_from_parent_transaction()
    |> InternalTransaction.where_nonpending_block()
    |> Repo.replica().all()
  end

  @doc """
  Gets a list of internal transactions for a given address hash
  (`t:Explorer.Chain.Hash.Address.t/0`).

  Note that this function relies on `Explorer.Chain` to exclude/include
  internal transactions as follows:

    * exclude internal transactions of type call with no siblings in the
      transaction
    * include internal transactions of type create, reward, or selfdestruct
      even when they are alone in the parent transaction

  """
  @spec list_internal_transactions(Hash.Address.t(), map()) :: [map()]
  def list_internal_transactions(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash,
        raw_options \\ %{}
      ) do
    options = Map.merge(@default_options, raw_options)

    direction =
      case options do
        %{filter_by: "to"} -> :to
        %{filter_by: "from"} -> :from
        _ -> nil
      end

    consensus_blocks =
      from(
        b in Block,
        where: b.consensus == true
      )

    if direction == nil do
      query =
        from(
          it in InternalTransaction,
          inner_join: b in subquery(consensus_blocks),
          on: it.block_number == b.number,
          order_by: [
            {^options.order_by_direction, it.block_number},
            {:desc, it.transaction_index},
            {:desc, it.index}
          ],
          limit: ^options.page_size,
          offset: ^offset(options),
          select:
            merge(map(it, ^@internal_transaction_fields), %{
              block_timestamp: b.timestamp,
              block_number: b.number
            })
        )

      query_to_address_hash_wrapped =
        query
        |> InternalTransaction.where_address_fields_match(address_hash, :to_address_hash)
        |> InternalTransaction.where_is_different_from_parent_transaction()
        |> where_start_block_match(options)
        |> where_end_block_match(options)
        |> Chain.wrapped_union_subquery()

      query_from_address_hash_wrapped =
        query
        |> InternalTransaction.where_address_fields_match(address_hash, :from_address_hash)
        |> InternalTransaction.where_is_different_from_parent_transaction()
        |> where_start_block_match(options)
        |> where_end_block_match(options)
        |> Chain.wrapped_union_subquery()

      query_created_contract_address_hash_wrapped =
        query
        |> InternalTransaction.where_address_fields_match(address_hash, :created_contract_address_hash)
        |> InternalTransaction.where_is_different_from_parent_transaction()
        |> where_start_block_match(options)
        |> where_end_block_match(options)
        |> Chain.wrapped_union_subquery()

      query_to_address_hash_wrapped
      |> union(^query_from_address_hash_wrapped)
      |> union(^query_created_contract_address_hash_wrapped)
      |> Repo.replica().all()
    else
      query =
        from(
          it in InternalTransaction,
          inner_join: t in assoc(it, :transaction),
          inner_join: b in assoc(t, :block),
          order_by: [{^options.order_by_direction, t.block_number}],
          limit: ^options.page_size,
          offset: ^offset(options),
          select:
            merge(map(it, ^@internal_transaction_fields), %{
              block_timestamp: b.timestamp,
              block_number: b.number
            })
        )

      query
      |> Chain.where_transaction_has_multiple_internal_transactions()
      |> InternalTransaction.where_address_fields_match(address_hash, direction)
      |> InternalTransaction.where_is_different_from_parent_transaction()
      |> where_start_block_match(options)
      |> where_end_block_match(options)
      |> InternalTransaction.where_nonpending_block()
      |> Repo.replica().all()
    end
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
    case Chain.max_consensus_block_number() do
      {:ok, block_height} ->
        merged_options = Map.merge(@default_options, options)
        list_token_transfers(address_hash, contract_address_hash, block_height, merged_options)

      _ ->
        []
    end
  end

  @doc """
  Gets a list of blocks mined by `t:Explorer.Chain.Hash.Address.t/0`.

  For each block it returns the block's number, timestamp, and reward.

  The block reward is the sum of the following:

  * Sum of the transaction fees (gas_used * gas_price) for the block
  * A static reward for miner (this value may change during the life of the chain)
  * The reward for uncle blocks (1/32 * static_reward * number_of_uncles)

  *NOTE*

  Uncles are not currently accounted for.

  """
  @spec list_blocks(Hash.Address.t()) :: [map()]
  def list_blocks(%Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash, options \\ %{}) do
    merged_options = Map.merge(@default_options, options)

    query =
      from(
        b in Block,
        where: b.miner_hash == ^address_hash,
        order_by: [desc: b.number],
        limit: ^merged_options.page_size,
        offset: ^offset(merged_options),
        select: %{
          number: b.number,
          timestamp: b.timestamp
        }
      )

    Repo.replica().all(query)
  end

  @doc """
  Gets the token balance for a given contract address hash and address hash.

  """
  @spec get_token_balance(Hash.Address.t(), Hash.Address.t()) :: TokenBalance.t() | nil
  def get_token_balance(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = contract_address_hash,
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash
      ) do
    query =
      from(
        ctb in CurrentTokenBalance,
        where: ctb.token_contract_address_hash == ^contract_address_hash,
        where: ctb.address_hash == ^address_hash,
        limit: 1,
        select: ctb
      )

    Repo.replica().one(query)
  end

  @doc """
  Gets a list of tokens owned by the given address hash.

  """
  @spec list_tokens(Hash.Address.t()) :: map() | []
  def list_tokens(%Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash) do
    query =
      from(
        ctb in CurrentTokenBalance,
        inner_join: t in assoc(ctb, :token),
        where: ctb.address_hash == ^address_hash,
        where: ctb.value > 0,
        distinct: :token_contract_address_hash,
        select: %{
          balance: ctb.value,
          contract_address_hash: ctb.token_contract_address_hash,
          name: t.name,
          decimals: t.decimals,
          symbol: t.symbol,
          type: t.type
        }
      )

    Repo.replica().all(query)
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
    revert_reason
  )a

  @pending_transaction_fields ~w(
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
    to_address_hash
    value
    inserted_at
  )a

  defp list_pending_transactions_query(address_hash, options) do
    query =
      from(
        t in Transaction,
        limit: ^options.page_size,
        offset: ^offset(options),
        select: map(t, ^@pending_transaction_fields)
      )

    query
    |> where_address_match(address_hash, options)
    |> Chain.pending_transactions_query()
    |> order_by([transaction], desc: transaction.inserted_at, desc: transaction.hash)
    |> Repo.replica().all()
  end

  defp list_transactions(address_hash, max_block_number, options) do
    query =
      from(
        t in Transaction,
        inner_join: b in assoc(t, :block),
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
    |> where_address_match(address_hash, options)
    |> where_start_block_match(options)
    |> where_end_block_match(options)
    |> where_start_timestamp_match(options)
    |> where_end_timestamp_match(options)
    |> Repo.replica().all()
  end

  defp where_address_match(query, address_hash, %{filter_by: "to"}) do
    where(query, [t], t.to_address_hash == ^address_hash)
  end

  defp where_address_match(query, address_hash, %{filter_by: "from"}) do
    where(query, [t], t.from_address_hash == ^address_hash)
  end

  defp where_address_match(query, address_hash, _) do
    query
    |> where([t], t.to_address_hash == ^address_hash)
    |> or_where([t], t.from_address_hash == ^address_hash)
    |> or_where([t], t.created_contract_address_hash == ^address_hash)
  end

  @token_transfer_fields ~w(
    block_number
    block_hash
    token_contract_address_hash
    transaction_hash
    from_address_hash
    to_address_hash
    amount
  )a

  defp list_token_transfers(address_hash, contract_address_hash, block_height, options) do
    tt_query =
      from(
        tt in TokenTransfer,
        inner_join: tkn in assoc(tt, :token),
        where: tt.from_address_hash == ^address_hash,
        or_where: tt.to_address_hash == ^address_hash,
        order_by: [{^options.order_by_direction, tt.block_number}, {^options.order_by_direction, tt.log_index}],
        limit: ^options.page_size,
        offset: ^offset(options),
        select:
          merge(map(tt, ^@token_transfer_fields), %{
            token_id: tt.token_id,
            token_name: tkn.name,
            token_symbol: tkn.symbol,
            token_decimals: tkn.decimals,
            token_type: tkn.type,
            token_log_index: tt.log_index
          })
      )

    tt_specific_token_query =
      tt_query
      |> where_contract_address_match(contract_address_hash)

    wrapped_query =
      from(
        tt in subquery(tt_specific_token_query),
        inner_join: t in Transaction,
        on: tt.transaction_hash == t.hash and tt.block_number == t.block_number and tt.block_hash == t.block_hash,
        inner_join: b in assoc(t, :block),
        order_by: [{^options.order_by_direction, tt.block_number}, {^options.order_by_direction, tt.token_log_index}],
        select: %{
          token_contract_address_hash: tt.token_contract_address_hash,
          transaction_hash: tt.transaction_hash,
          from_address_hash: tt.from_address_hash,
          to_address_hash: tt.to_address_hash,
          amount: tt.amount,
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
          confirmations: fragment("? - ?", ^block_height, t.block_number),
          token_id: tt.token_id,
          token_name: tt.token_name,
          token_symbol: tt.token_symbol,
          token_decimals: tt.token_decimals,
          token_type: tt.token_type,
          token_log_index: tt.token_log_index
        }
      )

    wrapped_query
    |> where_start_block_match(options)
    |> where_end_block_match(options)
    |> Repo.replica().all()
  end

  defp where_start_block_match(query, %{start_block: nil}), do: query

  defp where_start_block_match(query, %{start_block: start_block}) do
    where(query, [..., block], block.number >= ^start_block)
  end

  defp where_end_block_match(query, %{end_block: nil}), do: query

  defp where_end_block_match(query, %{end_block: end_block}) do
    where(query, [..., block], block.number <= ^end_block)
  end

  defp where_start_timestamp_match(query, %{start_timestamp: nil}), do: query

  defp where_start_timestamp_match(query, %{start_timestamp: start_timestamp}) do
    where(query, [..., block], ^start_timestamp <= block.timestamp)
  end

  defp where_end_timestamp_match(query, %{end_timestamp: nil}), do: query

  defp where_end_timestamp_match(query, %{end_timestamp: end_timestamp}) do
    where(query, [..., block], block.timestamp <= ^end_timestamp)
  end

  defp where_contract_address_match(query, nil), do: query

  defp where_contract_address_match(query, contract_address_hash) do
    where(query, [tt, _], tt.token_contract_address_hash == ^contract_address_hash)
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
