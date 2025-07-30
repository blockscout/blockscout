defmodule Explorer.Etherscan do
  @moduledoc """
  The etherscan context.
  """

  import Ecto.Query

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer.Etherscan.Logs
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Address.{CurrentTokenBalance, TokenBalance}
  alias Explorer.Chain.{Address, Block, DenormalizationHelper, Hash, InternalTransaction, TokenTransfer, Transaction}
  alias Explorer.Chain.Transaction.History.TransactionStats

  @default_options %{
    order_by_direction: :desc,
    include_zero_value: false,
    page_number: 1,
    page_size: 10_000,
    startblock: nil,
    endblock: nil,
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
    transaction_index
    index
    value
    created_contract_address_hash
    input
    type
    call_type
    gas
    gas_used
    error
  )a

  @doc """
  Gets a list of all internal transactions (with :all option) or for a given address hash
  (`t:Explorer.Chain.Hash.Address.t/0`) or transaction hash
  (`t:Explorer.Chain.Hash.Full.t/0`).

  Note that this function relies on `Explorer.Chain` to exclude/include
  internal transactions as follows:

    * exclude internal transactions of type call with no siblings in the
      transaction
    * include internal transactions of type create, reward, or selfdestruct
      even when they are alone in the parent transaction
  """
  @spec list_internal_transactions(Hash.Full.t() | Hash.Address.t() | :all, map()) :: [map()]
  def list_internal_transactions(transaction_or_address_hash_param_or_no_param, raw_options \\ %{})

  def list_internal_transactions(%Hash{byte_count: unquote(Hash.Full.byte_count())} = transaction_hash, raw_options) do
    options = Map.merge(@default_options, raw_options)

    query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        from(
          it in InternalTransaction,
          inner_join: transaction in assoc(it, :transaction),
          where: not is_nil(transaction.block_hash),
          where: it.transaction_hash == ^transaction_hash,
          limit: 10_000,
          select:
            merge(map(it, ^@internal_transaction_fields), %{
              block_timestamp: transaction.block_timestamp,
              block_number: transaction.block_number
            })
        )
      else
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
      end

    query
    |> InternalTransaction.where_transaction_has_multiple_internal_transactions()
    |> InternalTransaction.where_is_different_from_parent_transaction()
    |> InternalTransaction.where_nonpending_block()
    |> InternalTransaction.include_zero_value(options.include_zero_value)
    |> Repo.replica().all()
  end

  def list_internal_transactions(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash,
        raw_options
      ) do
    options = Map.merge(@default_options, raw_options)

    options
    |> options_to_directions()
    |> Enum.map(fn direction ->
      options
      |> consensus_internal_transactions_with_transactions_and_blocks_query()
      |> InternalTransaction.where_address_fields_match(address_hash, direction)
      |> InternalTransaction.where_is_different_from_parent_transaction()
      |> InternalTransaction.include_zero_value(options.include_zero_value)
      |> where_start_block_match_internal_transaction(options)
      |> where_end_block_match_internal_transaction(options)
      |> InternalTransaction.where_nonpending_block()
      |> Chain.wrapped_union_subquery()
    end)
    |> Enum.reduce(fn query, acc ->
      union(acc, ^query)
    end)
    |> Chain.wrapped_union_subquery()
    |> order_by(
      [q],
      [
        {^options.order_by_direction, q.block_number},
        {^options.order_by_direction, q.transaction_index},
        {^options.order_by_direction, q.index}
      ]
    )
    |> offset(^options_to_offset(options))
    |> limit(^options.page_size)
    |> Repo.replica().all()
  end

  def list_internal_transactions(
        :all,
        raw_options
      ) do
    options = Map.merge(@default_options, raw_options)

    consensus_blocks = Block.consensus_blocks_query()

    options
    |> internal_transactions_query(consensus_blocks)
    |> InternalTransaction.where_is_different_from_parent_transaction()
    |> InternalTransaction.include_zero_value(options.include_zero_value)
    |> where_start_block_match_internal_transaction(options)
    |> where_end_block_match_internal_transaction(options)
    |> Repo.replica().all()
  end

  defp consensus_internal_transactions_with_transactions_and_blocks_query(options) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      from(
        it in InternalTransaction,
        as: :internal_transaction,
        inner_join: transaction in assoc(it, :transaction),
        where: not is_nil(transaction.block_hash),
        where: transaction.block_consensus == true,
        order_by: [
          {^options.order_by_direction, it.block_number},
          {^options.order_by_direction, it.transaction_index},
          {^options.order_by_direction, it.index}
        ],
        limit: ^options_to_limit_for_inner_query(options),
        select:
          merge(map(it, ^@internal_transaction_fields), %{
            block_timestamp: transaction.block_timestamp,
            block_number: transaction.block_number
          })
      )
    else
      from(
        it in InternalTransaction,
        as: :internal_transaction,
        inner_join: t in assoc(it, :transaction),
        inner_join: b in assoc(t, :block),
        where: b.consensus == true,
        order_by: [
          {^options.order_by_direction, it.block_number},
          {^options.order_by_direction, it.transaction_index},
          {^options.order_by_direction, it.index}
        ],
        limit: ^options_to_limit_for_inner_query(options),
        select:
          merge(map(it, ^@internal_transaction_fields), %{
            block_timestamp: b.timestamp,
            block_number: b.number
          })
      )
    end
  end

  defp internal_transactions_query(options, consensus_blocks) do
    from(
      it in InternalTransaction,
      inner_join: block in subquery(consensus_blocks),
      on: it.block_number == block.number,
      order_by: [
        {^options.order_by_direction, it.block_number},
        {^options.order_by_direction, it.transaction_index},
        {^options.order_by_direction, it.index}
      ],
      limit: ^options.page_size,
      offset: ^options_to_offset(options),
      select:
        merge(map(it, ^@internal_transaction_fields), %{
          block_timestamp: block.timestamp,
          block_number: block.number
        })
    )
  end

  @doc """
  Retrieves token transfers filtered by token standard type with optional address and contract filtering.

  This function queries token transfers based on the specified token standard
  (ERC-20, ERC-721, ERC-1155, or ERC-404) and applies optional filtering by
  address and contract address. The function merges provided options with
  default settings for pagination, ordering, and block range filtering.

  For ERC-1155 transfers, the function performs additional processing to unnest
  arrays of token IDs and amounts into individual transfer records, with each
  record containing the specific token ID, amount, and index within the batch.

  ## Parameters
  - `token_transfers_type`: The token standard type (`:erc20`, `:erc721`,
    `:erc1155`, or `:erc404`)
  - `address_hash`: Optional address hash to filter transfers involving this
    address as sender or recipient (filters by `from_address_hash` or
    `to_address_hash`)
  - `contract_address_hash`: Optional contract address hash to filter transfers
    for a specific token contract
  - `options`: Map of query options that gets merged with default options
    including pagination (`page_number`, `page_size`), ordering
    (`order_by_direction`), and block range filtering (`startblock`, `endblock`)

  ## Returns
  - A list of `TokenTransfer` structs matching the specified criteria
  - For ERC-1155 transfers, each struct includes unnested `token_id`, `amount`,
    and `index_in_batch` fields
  """
  @spec list_token_transfers(
          :erc20 | :erc721 | :erc1155 | :erc404,
          Hash.Address.t() | nil,
          Hash.Address.t() | nil,
          map()
        ) :: [TokenTransfer.t()]
  def list_token_transfers(token_transfers_type, address_hash, contract_address_hash, options) do
    options = Map.merge(@default_options, options)

    case token_transfers_type do
      :erc20 ->
        list_erc20_token_transfers(address_hash, contract_address_hash, options)

      :erc721 ->
        list_nft_transfers(address_hash, contract_address_hash, options)

      :erc1155 ->
        list_erc1155_token_transfers(address_hash, contract_address_hash, options)

      :erc404 ->
        list_erc404_token_transfers(address_hash, contract_address_hash, options)
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
        block in Block,
        where: block.miner_hash == ^address_hash,
        order_by: [desc: block.number],
        limit: ^merged_options.page_size,
        offset: ^options_to_offset(merged_options),
        select: %{
          number: block.number,
          timestamp: block.timestamp
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
        select: %{
          balance: ctb.value,
          contract_address_hash: ctb.token_contract_address_hash,
          name: t.name,
          decimals: t.decimals,
          symbol: t.symbol,
          type: t.type,
          id: ctb.token_id
        }
      )

    Repo.replica().all(query)
  end

  @transaction_fields ~w(
    block_hash
    block_number
    block_consensus
    block_timestamp
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
        limit: ^options_to_limit_for_inner_query(options),
        select: map(t, ^@pending_transaction_fields)
      )

    options
    |> options_to_directions()
    |> Enum.map(fn direction ->
      query
      |> where_address_match(address_hash, direction)
      |> Chain.pending_transactions_query()
      |> order_by([transaction], desc: transaction.inserted_at, desc: transaction.hash)
      |> Chain.wrapped_union_subquery()
    end)
    |> Enum.reduce(fn query, acc ->
      union(acc, ^query)
    end)
    |> Chain.wrapped_union_subquery()
    |> order_by(
      [transaction],
      desc: transaction.inserted_at,
      desc: transaction.hash
    )
    |> offset(^options_to_offset(options))
    |> limit(^options.page_size)
    |> Repo.replica().all()
  end

  defp list_transactions(address_hash, max_block_number, options) do
    query =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        from(
          t in Transaction,
          where: not is_nil(t.block_hash),
          where: t.block_consensus == true,
          order_by: [{^options.order_by_direction, t.block_number}, {^options.order_by_direction, t.index}],
          limit: ^options_to_limit_for_inner_query(options),
          select:
            merge(map(t, ^@transaction_fields), %{
              confirmations: fragment("? - ?", ^max_block_number, t.block_number)
            })
        )
      else
        from(
          t in Transaction,
          inner_join: b in assoc(t, :block),
          where: b.consensus == true,
          order_by: [{^options.order_by_direction, t.block_number}, {^options.order_by_direction, t.index}],
          limit: ^options_to_limit_for_inner_query(options),
          select:
            merge(map(t, ^@transaction_fields), %{
              block_timestamp: b.timestamp,
              confirmations: fragment("? - ?", ^max_block_number, t.block_number)
            })
        )
      end

    options
    |> options_to_directions()
    |> Enum.map(fn direction ->
      query
      |> where_address_match(address_hash, direction)
      |> where_start_transaction_block_match(options)
      |> where_end_transaction_block_match(options)
      |> where_start_timestamp_match(options)
      |> where_end_timestamp_match(options)
      |> Chain.wrapped_union_subquery()
    end)
    |> Enum.reduce(fn query, acc ->
      union(acc, ^query)
    end)
    |> Chain.wrapped_union_subquery()
    |> order_by(
      [q],
      [
        {^options.order_by_direction, q.block_number},
        {^options.order_by_direction, q.index}
      ]
    )
    |> offset(^options_to_offset(options))
    |> limit(^options.page_size)
    |> Repo.replica().all()
  end

  defp where_address_match(query, address_hash, :to_address_hash) do
    where(query, [t], t.to_address_hash == ^address_hash)
  end

  defp where_address_match(query, address_hash, :from_address_hash) do
    where(query, [t], t.from_address_hash == ^address_hash)
  end

  defp where_address_match(query, address_hash, :created_contract_address_hash) do
    where(query, [t], t.created_contract_address_hash == ^address_hash)
  end

  defp list_erc20_token_transfers(address_hash, contract_address_hash, options) do
    "ERC-20" |> base_token_transfers_query(address_hash, contract_address_hash, options) |> Repo.all()
  end

  defp list_nft_transfers(address_hash, contract_address_hash, options) do
    "ERC-721" |> base_token_transfers_query(address_hash, contract_address_hash, options) |> Repo.all()
  end

  defp list_erc1155_token_transfers(address_hash, contract_address_hash, options) do
    "ERC-1155"
    |> base_token_transfers_query(address_hash, contract_address_hash, options)
    |> join(
      :inner,
      [token_transfer],
      unnest in fragment(
        "LATERAL (SELECT unnest(?) AS token_id, unnest(COALESCE(?, ARRAY[?])) AS amount, GENERATE_SERIES(0, COALESCE(ARRAY_LENGTH(?, 1), 0) - 1) as index_in_batch)",
        token_transfer.token_ids,
        token_transfer.amounts,
        token_transfer.amount,
        token_transfer.amounts
      ),
      as: :unnest,
      on: true
    )
    |> select_merge([unnest: unnest], %{
      token_id: fragment("?::numeric", unnest.token_id),
      amount: fragment("?::numeric", unnest.amount),
      index_in_batch: fragment("?::integer", unnest.index_in_batch)
    })
    |> order_by(
      [unnest: unnest],
      {^options.order_by_direction, unnest.index_in_batch}
    )
    |> Repo.all()
  end

  defp list_erc404_token_transfers(address_hash, contract_address_hash, options) do
    "ERC-404" |> base_token_transfers_query(address_hash, contract_address_hash, options) |> Repo.all()
  end

  defp base_token_transfers_query(transfers_type, address_hash, contract_address_hash, options) do
    TokenTransfer.only_consensus_transfers_query()
    |> TokenTransfer.maybe_filter_by_token_type(transfers_type)
    |> where_contract_address_match(contract_address_hash)
    |> where_address_match_token_transfer(address_hash)
    |> order_by([tt], [
      {^options.order_by_direction, tt.block_number},
      {^options.order_by_direction, tt.log_index}
    ])
    |> where_start_block_match_tt(options)
    |> where_end_block_match_tt(options)
    |> limit(^options.page_size)
    |> offset(^options_to_offset(options))
    |> maybe_preload_entities()
  end

  defp maybe_preload_entities(query) do
    if DenormalizationHelper.tt_denormalization_finished?() do
      query
      |> preload([:transaction, :token])
    else
      query
      |> preload([:block, :token, :transaction])
    end
  end

  defp where_start_block_match(query, %{startblock: nil}), do: query

  defp where_start_block_match(query, %{startblock: start_block}) do
    where(query, [..., block], block.number >= ^start_block)
  end

  defp where_end_block_match(query, %{endblock: nil}), do: query

  defp where_end_block_match(query, %{endblock: end_block}) do
    where(query, [..., block], block.number <= ^end_block)
  end

  defp where_start_transaction_block_match(query, %{startblock: nil}), do: query

  defp where_start_transaction_block_match(query, %{startblock: start_block} = params) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      where(query, [transaction], transaction.block_number >= ^start_block)
    else
      where_start_block_match(query, params)
    end
  end

  defp where_end_transaction_block_match(query, %{endblock: nil}), do: query

  defp where_end_transaction_block_match(query, %{endblock: end_block} = params) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      where(query, [transaction], transaction.block_number <= ^end_block)
    else
      where_end_block_match(query, params)
    end
  end

  defp where_start_block_match_tt(query, %{startblock: nil}), do: query

  defp where_start_block_match_tt(query, %{startblock: start_block}) do
    where(query, [tt], tt.block_number >= ^start_block)
  end

  defp where_end_block_match_tt(query, %{endblock: nil}), do: query

  defp where_end_block_match_tt(query, %{endblock: end_block}) do
    where(query, [tt], tt.block_number <= ^end_block)
  end

  defp where_start_block_match_internal_transaction(query, %{startblock: nil}), do: query

  defp where_start_block_match_internal_transaction(query, %{startblock: start_block}) do
    where(query, [internal_transaction: internal_transaction], internal_transaction.block_number >= ^start_block)
  end

  defp where_end_block_match_internal_transaction(query, %{endblock: nil}), do: query

  defp where_end_block_match_internal_transaction(query, %{endblock: end_block}) do
    where(query, [internal_transaction: internal_transaction], internal_transaction.block_number <= ^end_block)
  end

  defp where_start_timestamp_match(query, %{start_timestamp: nil}), do: query

  defp where_start_timestamp_match(query, %{start_timestamp: start_timestamp}) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      where(query, [transaction], ^start_timestamp <= transaction.block_timestamp)
    else
      where(query, [..., block], ^start_timestamp <= block.timestamp)
    end
  end

  defp where_end_timestamp_match(query, %{end_timestamp: nil}), do: query

  defp where_end_timestamp_match(query, %{end_timestamp: end_timestamp}) do
    if DenormalizationHelper.transactions_denormalization_finished?() do
      where(query, [transaction], transaction.block_timestamp <= ^end_timestamp)
    else
      where(query, [..., block], block.timestamp <= ^end_timestamp)
    end
  end

  defp where_contract_address_match(query, nil), do: query

  defp where_contract_address_match(query, contract_address_hash) do
    where(query, [tt], tt.token_contract_address_hash == ^contract_address_hash)
  end

  defp where_address_match_token_transfer(query, nil), do: query

  defp where_address_match_token_transfer(query, address_hash) do
    where(query, [tt], tt.from_address_hash == ^address_hash or tt.to_address_hash == ^address_hash)
  end

  defp options_to_offset(options), do: (options.page_number - 1) * options.page_size

  defp options_to_limit_for_inner_query(options), do: options.page_number * options.page_size

  defp options_to_directions(options) do
    case options do
      %{filter_by: "to"} -> [:to_address_hash, :created_contract_address_hash]
      %{filter_by: "from"} -> [:from_address_hash]
      _ -> [:to_address_hash, :from_address_hash, :created_contract_address_hash]
    end
  end

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

  @spec fetch_sum_coin_total_supply() :: non_neg_integer
  def fetch_sum_coin_total_supply do
    query =
      from(
        a0 in Address,
        select: fragment("SUM(a0.fetched_coin_balance)"),
        where: a0.fetched_coin_balance > ^0
      )

    Repo.replica().one!(query, timeout: :infinity) || 0
  end

  @spec fetch_sum_coin_total_supply_minus_burnt() :: non_neg_integer
  def fetch_sum_coin_total_supply_minus_burnt do
    {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())

    query =
      from(
        a0 in Address,
        select: fragment("SUM(a0.fetched_coin_balance)"),
        where: a0.hash != ^burn_address_hash,
        where: a0.fetched_coin_balance > ^0
      )

    Repo.replica().one!(query, timeout: :infinity) || 0
  end

  @doc """
  It is used by `totalfees` API endpoint of `stats` module for retrieving of total fee per day
  """
  @spec get_total_fees_per_day(String.t()) :: {:ok, non_neg_integer() | nil} | {:error, String.t()}
  def get_total_fees_per_day(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        query =
          from(
            transaction_stats in TransactionStats,
            where: transaction_stats.date == ^date,
            select: transaction_stats.total_fee
          )

        total_fees = Repo.replica().one(query)
        {:ok, total_fees}

      _ ->
        {:error, "An incorrect input date provided. It should be in ISO 8601 format (yyyy-mm-dd)."}
    end
  end
end
