defmodule Explorer.Chain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query,
    only: [
      from: 2,
      join: 4,
      join: 5,
      limit: 2,
      lock: 2,
      order_by: 2,
      order_by: 3,
      preload: 2,
      select: 2,
      select: 3,
      subquery: 1,
      union: 2,
      where: 2,
      where: 3
    ]

  import EthereumJSONRPC, only: [integer_to_quantity: 1, json_rpc: 2, fetch_block_internal_transactions: 2]

  require Logger

  alias ABI.{TypeDecoder, TypeEncoder}
  alias Ecto.Adapters.SQL
  alias Ecto.{Changeset, Multi, Query}

  alias EthereumJSONRPC.Contract
  alias EthereumJSONRPC.Transaction, as: EthereumJSONRPCTransaction

  alias Explorer.Counters.LastFetchedCounter

  alias Explorer.Chain

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Address.CoinBalanceDaily,
    Address.CurrentTokenBalance,
    Address.TokenBalance,
    Block,
    BridgedToken,
    CeloAccount,
    CeloClaims,
    CeloParams,
    CeloSigners,
    CeloUnlocked,
    CeloValidator,
    CeloValidatorGroup,
    CeloValidatorHistory,
    CeloVoters,
    CurrencyHelpers,
    Data,
    DecompiledSmartContract,
    ExchangeRate,
    Hash,
    Import,
    InternalTransaction,
    Log,
    PendingBlockOperation,
    ProxyContract,
    SmartContract,
    SmartContractAdditionalSource,
    StakingPool,
    StakingPoolsDelegator,
    Token,
    Token.Instance,
    TokenTransfer,
    Transaction,
    Wei
  }

  alias Explorer.Chain.Block.{EmissionReward, Reward}

  alias Explorer.Chain.Cache.{
    Accounts,
    BlockCount,
    BlockNumber,
    Blocks,
    TokenExchangeRate,
    Transactions,
    Uncles
  }

  alias Explorer.Chain.Celo.ContractEventTracking
  alias Explorer.Chain.Celo.TransactionStats, as: CeloTxStats

  alias Explorer.Chain.Import.Runner
  alias Explorer.Chain.InternalTransaction.{CallType, Type}
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Counters.{AddressesCounter, AddressesWithBalanceCounter}
  alias Explorer.Market.MarketHistoryCache
  alias Explorer.{PagingOptions, Repo}
  alias Explorer.SmartContract.Reader
  alias Explorer.Staking.ContractState

  alias Dataloader.Ecto, as: DataloaderEcto

  @default_paging_options %PagingOptions{page_size: 50}

  @max_incoming_transactions_count 10_000

  @revert_msg_prefix_1 "Revert: "
  @revert_msg_prefix_2 "revert: "
  @revert_msg_prefix_3 "reverted "
  @revert_msg_prefix_4 "Reverted "
  @revert_msg_prefix_5 "execution reverted: "
  # keccak256("Error(string)")
  @revert_error_method_id "08c379a0"

  @burn_address_hash_str "0x0000000000000000000000000000000000000000"

  @typedoc """
  The name of an association on the `t:Ecto.Schema.t/0`
  """
  @type association :: atom()

  @typedoc """
  The max `t:Explorer.Chain.Block.block_number/0` for `consensus` `true` `t:Explorer.Chain.Block.t/0`s.
  """
  @type block_height :: Block.block_number()

  @typedoc """
  Event type where data is broadcasted whenever data is inserted from chain indexing.
  """
  @type chain_event ::
          :addresses
          | :address_coin_balances
          | :blocks
          | :block_rewards
          | :exchange_rate
          | :internal_transactions
          | :logs
          | :transactions
          | :token_transfers

  @type direction :: :from | :to

  @typedoc """
   * `:optional` - the association is optional and only needs to be loaded if available
   * `:required` - the association is required and MUST be loaded.  If it is not available, then the parent struct
     SHOULD NOT be returned.
  """
  @type necessity :: :optional | :required

  @typedoc """
  The `t:necessity/0` of each association that should be loaded
  """
  @type necessity_by_association :: %{association => necessity}

  @typep necessity_by_association_option :: {:necessity_by_association, necessity_by_association}
  @typep paging_options :: {:paging_options, PagingOptions.t()}
  @typep balance_by_day :: %{date: String.t(), value: Wei.t()}

  @doc """
  Gets from the cache the count of `t:Explorer.Chain.Address.t/0`'s where the `fetched_coin_balance` is > 0
  """
  @spec count_addresses_with_balance_from_cache :: non_neg_integer()
  def count_addresses_with_balance_from_cache do
    AddressesWithBalanceCounter.fetch()
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Address.t/0`.

  Estimated count of addresses.
  """
  @spec address_estimated_count() :: non_neg_integer()
  def address_estimated_count do
    cached_value = AddressesCounter.fetch()

    if is_nil(cached_value) do
      %Postgrex.Result{rows: [[count]]} = Repo.query!("SELECT reltuples FROM pg_class WHERE relname = 'addresses';")

      count
    else
      cached_value
    end
  end

  @doc """
  Counts the number of addresses with fetched coin balance > 0.

  This function should be used with caution. In larger databases, it may take a
  while to have the return back.
  """
  def count_addresses_with_balance do
    Repo.one(
      Address.count_with_fetched_coin_balance(),
      timeout: :infinity
    )
  end

  @doc """
  Counts the number of all addresses.

  This function should be used with caution. In larger databases, it may take a
  while to have the return back.
  """
  def count_addresses do
    Repo.one(
      Address.count(),
      timeout: :infinity
    )
  end

  @doc """
  `t:Explorer.Chain.InternalTransaction/0`s from the address with the given `hash`.

  This function excludes any internal transactions in the results where the
  internal transaction has no siblings within the parent transaction.

  ## Options

    * `:direction` - if specified, will filter internal transactions by address type. If `:to` is specified, only
      internal transactions where the "to" address matches will be returned. Likewise, if `:from` is specified, only
      internal transactions where the "from" address matches will be returned. If `:direction` is omitted, internal
      transactions either to or from the address will be returned.
    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`. If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, transaction_index, index}`) and. Results will be the internal
      transactions older than the `block_number`, `transaction index`, and `index` that are passed.

  """
  @spec address_to_internal_transactions(Hash.Address.t(), [paging_options | necessity_by_association_option]) :: [
          InternalTransaction.t()
        ]
  def address_to_internal_transactions(hash, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    direction = Keyword.get(options, :direction)

    from_block = from_block(options)
    to_block = to_block(options)

    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    if direction == nil do
      query_to_address_hash_wrapped =
        InternalTransaction
        |> InternalTransaction.where_nonpending_block()
        |> InternalTransaction.where_address_fields_match(hash, :to_address_hash)
        |> InternalTransaction.where_block_number_in_period(from_block, to_block)
        |> common_where_limit_order(paging_options)
        |> wrapped_union_subquery()

      query_from_address_hash_wrapped =
        InternalTransaction
        |> InternalTransaction.where_nonpending_block()
        |> InternalTransaction.where_address_fields_match(hash, :from_address_hash)
        |> InternalTransaction.where_block_number_in_period(from_block, to_block)
        |> common_where_limit_order(paging_options)
        |> wrapped_union_subquery()

      query_created_contract_address_hash_wrapped =
        InternalTransaction
        |> InternalTransaction.where_nonpending_block()
        |> InternalTransaction.where_address_fields_match(hash, :created_contract_address_hash)
        |> InternalTransaction.where_block_number_in_period(from_block, to_block)
        |> common_where_limit_order(paging_options)
        |> wrapped_union_subquery()

      full_query =
        query_to_address_hash_wrapped
        |> union(^query_from_address_hash_wrapped)
        |> union(^query_created_contract_address_hash_wrapped)

      full_query
      |> wrapped_union_subquery()
      |> order_by(
        [q],
        desc: q.block_number,
        desc: q.transaction_index,
        desc: q.index
      )
      |> preload(transaction: :block)
      |> join_associations(necessity_by_association)
      |> Repo.all()
    else
      InternalTransaction
      |> InternalTransaction.where_nonpending_block()
      |> InternalTransaction.where_address_fields_match(hash, direction)
      |> InternalTransaction.where_block_number_in_period(from_block, to_block)
      |> common_where_limit_order(paging_options)
      |> preload(transaction: :block)
      |> join_associations(necessity_by_association)
      |> Repo.all()
    end
  end

  def wrapped_union_subquery(query) do
    from(
      q in subquery(query),
      select: q
    )
  end

  defp common_where_limit_order(query, paging_options) do
    query
    |> InternalTransaction.where_is_different_from_parent_transaction()
    |> InternalTransaction.where_block_number_is_not_null()
    |> page_internal_transaction(paging_options, %{index_int_tx_desc_order: true})
    |> limit(^paging_options.page_size)
    |> order_by(
      [it],
      desc: it.block_number,
      desc: it.transaction_index,
      desc: it.index
    )
  end

  @doc """
  Get the total number of transactions sent by the address with the given hash according to the last block indexed.

  We have to increment +1 in the last nonce result because it works like an array position, the first
  nonce has the value 0. When last nonce is nil, it considers that the given address has 0 transactions.
  """
  @spec total_transactions_sent_by_address(Hash.Address.t()) :: non_neg_integer()
  def total_transactions_sent_by_address(address_hash) do
    last_nonce =
      address_hash
      |> Transaction.last_nonce_by_address_query()
      |> Repo.one(timeout: :infinity)

    case last_nonce do
      nil -> 0
      value -> value + 1
    end
  end

  @doc """
  Fetches the transactions related to the address with the given hash, including
  transactions that only have the address in the `token_transfers` related table
  and rewards for block validation.

  This query is divided into multiple subqueries intentionally in order to
  improve the listing performance.

  The `token_trasfers` table tends to grow exponentially, and the query results
  with a `transactions` `join` statement takes too long.

  To solve this the `transaction_hashes` are fetched in a separate query, and
  paginated through the `block_number` already present in the `token_transfers`
  table.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, index}`) and. Results will be the transactions older than
      the `block_number` and `index` that are passed.

  """
  @spec address_to_transactions_with_rewards(Hash.Address.t(), [paging_options | necessity_by_association_option]) ::
          [
            Transaction.t()
          ]
  def address_to_transactions_with_rewards(address_hash, options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    if Application.get_env(:block_scout_web, BlockScoutWeb.Chain)[:has_emission_funds] do
      cond do
        Keyword.get(options, :direction) == :from ->
          address_to_transactions_without_rewards(address_hash, options)

        address_has_rewards?(address_hash) ->
          %{payout_key: block_miner_payout_address} = Reward.get_validator_payout_key_by_mining(address_hash)

          if block_miner_payout_address && address_hash == block_miner_payout_address do
            transactions_with_rewards_results(address_hash, options, paging_options)
          else
            address_to_transactions_without_rewards(address_hash, options)
          end

        true ->
          address_to_transactions_without_rewards(address_hash, options)
      end
    else
      address_to_transactions_without_rewards(address_hash, options)
    end
  end

  defp transactions_with_rewards_results(address_hash, options, paging_options) do
    blocks_range = address_to_transactions_tasks_range_of_blocks(address_hash, options)

    rewards_task =
      Task.async(fn -> Reward.fetch_emission_rewards_tuples(address_hash, paging_options, blocks_range) end)

    [rewards_task | address_to_transactions_tasks(address_hash, options)]
    |> wait_for_address_transactions()
    |> Enum.sort_by(fn item ->
      case item do
        {%Reward{} = emission_reward, _} ->
          {-emission_reward.block.number, 1}

        item ->
          block_number = if item.block_number, do: -item.block_number, else: 0
          index = if item.index, do: -item.index, else: 0
          {block_number, index}
      end
    end)
    |> Enum.dedup_by(fn item ->
      case item do
        {%Reward{} = emission_reward, _} ->
          {emission_reward.block_hash, emission_reward.address_hash, emission_reward.address_type}

        transaction ->
          transaction.hash
      end
    end)
    |> Enum.take(paging_options.page_size)
  end

  def address_to_transactions_without_rewards(address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    address_hash
    |> address_to_transactions_tasks(options)
    |> wait_for_address_transactions()
    |> Enum.sort_by(&{&1.block_number, &1.index}, &>=/2)
    |> Enum.dedup_by(& &1.hash)
    |> Enum.take(paging_options.page_size)
  end

  def address_to_mined_transactions_without_rewards(address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    address_hash
    |> address_to_mined_transactions_tasks(options)
    |> wait_for_address_transactions()
    |> Enum.sort_by(&{&1.block_number, &1.index}, &>=/2)
    |> Enum.dedup_by(& &1.hash)
    |> Enum.take(paging_options.page_size)
  end

  defp address_to_transactions_tasks_query(options) do
    from_block = from_block(options)
    to_block = to_block(options)

    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions(from_block, to_block)
  end

  defp transactions_block_numbers_at_address(address_hash, options) do
    direction = Keyword.get(options, :direction)

    options
    |> address_to_transactions_tasks_query()
    |> Transaction.not_pending_transactions()
    |> select([t], t.block_number)
    |> Transaction.matching_address_queries_list(direction, address_hash)
  end

  defp address_to_transactions_tasks(address_hash, options) do
    direction = Keyword.get(options, :direction)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    from_block = from_block(options)
    to_block = to_block(options)

    options
    |> address_to_transactions_tasks_query()
    |> Transaction.not_dropped_or_replaced_transacions()
    |> where_block_number_in_period(from_block, to_block)
    |> join_associations(necessity_by_association)
    |> Transaction.matching_address_queries_list(direction, address_hash)
    |> Enum.map(fn query -> Task.async(fn -> Repo.all(query) end) end)
  end

  defp address_to_mined_transactions_tasks(address_hash, options) do
    direction = Keyword.get(options, :direction)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    options
    |> address_to_transactions_tasks_query()
    |> Transaction.not_pending_transactions()
    |> join_associations(necessity_by_association)
    |> Transaction.matching_address_queries_list(direction, address_hash)
    |> Enum.map(fn query -> Task.async(fn -> Repo.all(query) end) end)
  end

  def address_to_transactions_tasks_range_of_blocks(address_hash, options) do
    extremums_list =
      address_hash
      |> transactions_block_numbers_at_address(options)
      |> Enum.map(fn query ->
        extremum_query =
          from(
            q in subquery(query),
            select: %{min_block_number: min(q.block_number), max_block_number: max(q.block_number)}
          )

        extremum_query
        |> Repo.one!()
      end)

    extremums_list
    |> Enum.reduce(%{min_block_number: nil, max_block_number: 0}, fn %{
                                                                       min_block_number: min_number,
                                                                       max_block_number: max_number
                                                                     },
                                                                     extremums_result ->
      current_min_number = Map.get(extremums_result, :min_block_number)
      current_max_number = Map.get(extremums_result, :max_block_number)

      extremums_result =
        if is_number(current_min_number) do
          if is_number(min_number) and min_number > 0 and min_number < current_min_number do
            extremums_result
            |> Map.put(:min_block_number, min_number)
          else
            extremums_result
          end
        else
          extremums_result
          |> Map.put(:min_block_number, min_number)
        end

      if is_number(max_number) and max_number > 0 and max_number > current_max_number do
        extremums_result
        |> Map.put(:max_block_number, max_number)
      else
        extremums_result
      end
    end)
  end

  defp wait_for_address_transactions(tasks) do
    tasks
    |> Task.yield_many(:timer.seconds(20))
    |> Enum.flat_map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching address transactions terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching address transactions timed out."
      end
    end)
  end

  @spec address_hash_to_token_transfers(Hash.Address.t(), Keyword.t()) :: [Transaction.t()]
  def address_hash_to_token_transfers(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    direction = Keyword.get(options, :direction)

    direction
    |> Transaction.transactions_with_token_transfers_direction(address_hash)
    |> Transaction.preload_token_transfers(address_hash)
    |> handle_paging_options(paging_options)
    |> Repo.all()
  end

  @spec address_to_logs(Hash.Address.t(), Keyword.t()) :: [Log.t()]
  def address_to_logs(address_hash, options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options) || %PagingOptions{page_size: 50}

    from_block = from_block(options)
    to_block = to_block(options)

    {block_number, transaction_index, log_index} = paging_options.key || {BlockNumber.get_max(), 0, 0}

    base_query =
      from(log in Log,
        order_by: [desc: log.block_number, desc: log.index],
        where: log.block_number < ^block_number,
        or_where: log.block_number == ^block_number and log.index > ^log_index,
        where: log.address_hash == ^address_hash,
        limit: ^paging_options.page_size,
        select: log
      )

    wrapped_query =
      from(
        log in subquery(base_query),
        left_join: transaction in Transaction,
        on: log.transaction_hash == transaction.hash,
        preload: [
          :transaction,
          #          transaction: [to_address: :smart_contract],
          #          transaction: [to_address: [implementation_contract: :smart_contract]]
          address: :smart_contract,
          address: [implementation_contract: :smart_contract]
        ],
        select: log
      )

    wrapped_query
    |> filter_topic(options)
    |> where_block_number_in_period(from_block, to_block)
    |> Repo.all()
    |> Enum.take(paging_options.page_size)
  end

  defp filter_topic(base_query, topic: topic) do
    from(log in base_query,
      where:
        log.first_topic == ^topic or log.second_topic == ^topic or log.third_topic == ^topic or
          log.fourth_topic == ^topic
    )
  end

  defp filter_topic(base_query, _), do: base_query

  def where_block_number_in_period(base_query, from_block, to_block) when is_nil(from_block) and not is_nil(to_block) do
    from(q in base_query,
      where: q.block_number <= ^to_block
    )
  end

  def where_block_number_in_period(base_query, from_block, to_block) when not is_nil(from_block) and is_nil(to_block) do
    from(q in base_query,
      where: q.block_number > ^from_block
    )
  end

  def where_block_number_in_period(base_query, from_block, to_block) when is_nil(from_block) and is_nil(to_block) do
    from(q in base_query,
      where: 1
    )
  end

  def where_block_number_in_period(base_query, from_block, to_block) do
    from(q in base_query,
      where: q.block_number > ^from_block and q.block_number <= ^to_block
    )
  end

  @doc """
  Finds all `t:Explorer.Chain.Transaction.t/0`s given the address_hash and the token contract
  address hash.

  ## Options

    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (in the form of `%{"inserted_at" => inserted_at}`). Results will be the transactions
      older than the `index` that are passed.
  """
  @spec address_to_transactions_with_token_transfers(Hash.t(), Hash.t(), [paging_options]) :: [Transaction.t()]
  def address_to_transactions_with_token_transfers(address_hash, token_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    address_hash
    |> Transaction.transactions_with_token_transfers(token_hash)
    |> Transaction.preload_token_transfers(address_hash)
    |> handle_paging_options(paging_options)
    |> Repo.all()
  end

  @doc """
  The `t:Explorer.Chain.Address.t/0` `balance` in `unit`.
  """
  @spec balance(Address.t(), :wei) :: Wei.wei() | nil
  @spec balance(Address.t(), :gwei) :: Wei.gwei() | nil
  @spec balance(Address.t(), :ether) :: Wei.ether() | nil
  def balance(%Address{fetched_coin_balance: balance}, unit) do
    case balance do
      nil -> nil
      _ -> Wei.to(balance, unit)
    end
  end

  @doc """
  The number of `t:Explorer.Chain.Block.t/0`.

      iex> insert_list(2, :block)
      iex> Explorer.Chain.block_count()
      2

  When there are no `t:Explorer.Chain.Block.t/0`.

      iex> Explorer.Chain.block_count()
      0

  """
  def block_count do
    Repo.aggregate(Block, :count, :hash)
  end

  @doc """
  Reward for mining a block.

  The block reward is the sum of the following:

  * Sum of the transaction fees (gas_used * gas_price) for the block
  * A static reward for miner (this value may change during the life of the chain)
  * The reward for uncle blocks (1/32 * static_reward * number_of_uncles)

  *NOTE*

  Uncles are not currently accounted for.
  """
  @spec block_reward(Block.block_number()) :: Wei.t()
  def block_reward(block_number) do
    query =
      from(
        block in Block,
        left_join: transaction in assoc(block, :transactions),
        inner_join: emission_reward in EmissionReward,
        on: fragment("? <@ ?", block.number, emission_reward.block_range),
        where: block.number == ^block_number,
        group_by: emission_reward.reward,
        select: %Wei{
          value: coalesce(sum(transaction.gas_used * transaction.gas_price), 0) + emission_reward.reward
        }
      )

    Repo.one!(query)
  end

  @doc """
  The `t:Explorer.Chain.Wei.t/0` paid to the miners of the `t:Explorer.Chain.Block.t/0`s with `hash`
  `Explorer.Chain.Hash.Full.t/0` by the signers of the transactions in those blocks to cover the gas fee
  (`gas_used * gas_price`).
  """
  @spec gas_payment_by_block_hash([Hash.Full.t()]) :: %{Hash.Full.t() => Wei.t()}
  def gas_payment_by_block_hash(block_hashes) when is_list(block_hashes) do
    query =
      from(
        block in Block,
        left_join: transaction in assoc(block, :transactions),
        where: block.hash in ^block_hashes and block.consensus == true,
        group_by: block.hash,
        select: {block.hash, %Wei{value: coalesce(sum(transaction.gas_used * transaction.gas_price), 0)}}
      )

    query
    |> Repo.all()
    |> Enum.into(%{})
  end

  def timestamp_by_block_hash(block_hashes) when is_list(block_hashes) do
    query =
      from(
        block in Block,
        where: block.hash in ^block_hashes and block.consensus == true,
        group_by: block.hash,
        select: {block.hash, block.timestamp}
      )

    query
    |> Repo.all()
    |> Enum.into(%{})
  end

  def timestamp_by_block_hash(block_hash) do
    query =
      from(
        block in Block,
        where: block.hash == ^block_hash and block.consensus == true,
        select: block.timestamp
      )

    query
    |> Repo.one()
  end

  @doc """
  Finds all `t:Explorer.Chain.Transaction.t/0`s in the `t:Explorer.Chain.Block.t/0`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{index}`) and. Results will be the transactions older than
      the `index` that are passed.
  """
  @spec block_to_transactions(Hash.Full.t(), [paging_options | necessity_by_association_option]) :: [Transaction.t()]
  def block_to_transactions(block_hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions_in_ascending_order_by_index()
    |> join(:inner, [transaction], block in assoc(transaction, :block))
    |> where([_, block], block.hash == ^block_hash)
    |> join_associations(necessity_by_association)
    |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
    |> Repo.all()
  end

  @doc """
  Finds sum of gas_used for new (EIP-1559) txs belongs to block
  """
  @spec block_to_gas_used_by_1559_txs(Hash.Full.t()) :: non_neg_integer()
  def block_to_gas_used_by_1559_txs(block_hash) do
    query =
      from(
        tx in Transaction,
        where: tx.block_hash == ^block_hash,
        where: not is_nil(tx.max_priority_fee_per_gas),
        select: sum(tx.gas_used)
      )

    result = Repo.one(query)
    if result, do: result, else: 0
  end

  @doc """
  Finds sum of priority fee for new (EIP-1559) txs belongs to block
  """
  @spec block_to_priority_fee_of_1559_txs(Hash.Full.t()) :: Decimal.t()
  def block_to_priority_fee_of_1559_txs(block_hash) do
    block = Repo.get_by(Block, hash: block_hash)
    %Wei{value: base_fee_per_gas} = block.base_fee_per_gas

    query =
      from(
        tx in Transaction,
        where: tx.block_hash == ^block_hash,
        where: not is_nil(tx.max_priority_fee_per_gas),
        select:
          sum(
            fragment(
              "CASE 
                WHEN ? = 0 THEN 0
                WHEN ? < ? THEN ?
                ELSE ? END",
              tx.max_fee_per_gas,
              tx.max_fee_per_gas - ^base_fee_per_gas,
              tx.max_priority_fee_per_gas,
              (tx.max_fee_per_gas - ^base_fee_per_gas) * tx.gas_used,
              tx.max_priority_fee_per_gas * tx.gas_used
            )
          )
      )

    result = Repo.one(query)
    if result, do: result, else: 0
  end

  @doc """
  Counts the number of `t:Explorer.Chain.Transaction.t/0` in the `block`.
  """
  @spec block_to_transaction_count(Hash.Full.t()) :: non_neg_integer()
  def block_to_transaction_count(block_hash) do
    query =
      from(
        transaction in Transaction,
        where: transaction.block_hash == ^block_hash
      )

    Repo.aggregate(query, :count, :hash)
  end

  @spec address_to_incoming_transaction_count(Hash.Address.t()) :: non_neg_integer()
  def address_to_incoming_transaction_count(address_hash) do
    to_address_query =
      from(
        transaction in Transaction,
        where: transaction.to_address_hash == ^address_hash
      )

    Repo.aggregate(to_address_query, :count, :hash, timeout: :infinity)
  end

  @spec address_to_incoming_transaction_gas_usage(Hash.Address.t()) :: non_neg_integer()
  def address_to_incoming_transaction_gas_usage(address_hash) do
    to_address_query =
      from(
        transaction in Transaction,
        where: transaction.to_address_hash == ^address_hash
      )

    Repo.aggregate(to_address_query, :sum, :gas_used, timeout: :infinity)
  end

  @spec address_to_outcoming_transaction_gas_usage(Hash.Address.t()) :: non_neg_integer()
  def address_to_outcoming_transaction_gas_usage(address_hash) do
    to_address_query =
      from(
        transaction in Transaction,
        where: transaction.from_address_hash == ^address_hash
      )

    Repo.aggregate(to_address_query, :sum, :gas_used, timeout: :infinity)
  end

  @spec max_incoming_transactions_count() :: non_neg_integer()
  def max_incoming_transactions_count, do: @max_incoming_transactions_count

  @doc """
  How many blocks have confirmed `block` based on the current `max_block_number`

  A consensus block's number of confirmations is the difference between its number and the current block height + 1.

      iex> block = insert(:block, number: 1)
      iex> Explorer.Chain.confirmations(block, block_height: 2)
      {:ok, 2}

  The newest block at the block height has 1 confirmation.

      iex> block = insert(:block, number: 1)
      iex> Explorer.Chain.confirmations(block, block_height: 1)
      {:ok, 1}

  A non-consensus block has no confirmations and is orphaned even if there are child blocks of it on an orphaned chain.

      iex> parent_block = insert(:block, consensus: false, number: 1)
      iex> insert(
      ...>   :block,
      ...>   parent_hash: parent_block.hash,
      ...>   consensus: false,
      ...>   number: parent_block.number + 1
      ...> )
      iex> Explorer.Chain.confirmations(parent_block, block_height: 3)
      {:error, :non_consensus}

  If you calculate the block height and then get a newer block, the confirmations will be `0` instead of negative.

      iex> block = insert(:block, number: 1)
      iex> Explorer.Chain.confirmations(block, block_height: 0)
      {:ok, 1}
  """
  @spec confirmations(Block.t(), [{:block_height, block_height()}]) ::
          {:ok, non_neg_integer()} | {:error, :non_consensus}

  def confirmations(%Block{consensus: true, number: number}, named_arguments) when is_list(named_arguments) do
    max_consensus_block_number = Keyword.fetch!(named_arguments, :block_height)

    {:ok, max(1 + max_consensus_block_number - number, 1)}
  end

  def confirmations(%Block{consensus: false}, _), do: {:error, :non_consensus}

  @doc """
  Creates an address.

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.create_address(
      ...>   %{hash: "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b"}
      ...> )
      ...> to_string(hash)
      "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b"

  A `String.t/0` value for `Explorer.Chain.Address.t/0` `hash` must have 40 hexadecimal characters after the `0x` prefix
  to prevent short- and long-hash transcription errors.

      iex> {:error, %Ecto.Changeset{errors: errors}} = Explorer.Chain.create_address(
      ...>   %{hash: "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0"}
      ...> )
      ...> errors
      [hash: {"is invalid", [type: Explorer.Chain.Hash.Address, validation: :cast]}]
      iex> {:error, %Ecto.Changeset{errors: errors}} = Explorer.Chain.create_address(
      ...>   %{hash: "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0ba"}
      ...> )
      ...> errors
      [hash: {"is invalid", [type: Explorer.Chain.Hash.Address, validation: :cast]}]

  """
  @spec create_address(map()) :: {:ok, Address.t()} | {:error, Ecto.Changeset.t()}
  def create_address(attrs \\ %{}) do
    %Address{}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a decompiled smart contract.
  """

  @spec create_decompiled_smart_contract(map()) :: {:ok, Address.t()} | {:error, Ecto.Changeset.t()}
  def create_decompiled_smart_contract(attrs) do
    changeset = DecompiledSmartContract.changeset(%DecompiledSmartContract{}, attrs)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    Multi.new()
    |> Multi.run(:set_address_decompiled, fn repo, _ ->
      set_address_decompiled(repo, Changeset.get_field(changeset, :address_hash))
    end)
    |> Multi.insert(:decompiled_smart_contract, changeset,
      on_conflict: :replace_all,
      conflict_target: [:decompiler_version, :address_hash]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{decompiled_smart_contract: decompiled_smart_contract}} -> {:ok, decompiled_smart_contract}
      {:error, _, error_value, _} -> {:error, error_value}
    end
  end

  @doc """
  Converts the `Explorer.Chain.Data.t:t/0` to `iodata` representation that can be written to users efficiently.

      iex> %Explorer.Chain.Data{
      ...>   bytes: <<>>
      ...> } |>
      ...> Explorer.Chain.data_to_iodata() |>
      ...> IO.iodata_to_binary()
      "0x"
      iex> %Explorer.Chain.Data{
      ...>   bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 134, 45, 103, 203, 7,
      ...>     115, 238, 63, 140, 231, 234, 137, 179, 40, 255, 234, 134, 26,
      ...>     179, 239>>
      ...> } |>
      ...> Explorer.Chain.data_to_iodata() |>
      ...> IO.iodata_to_binary()
      "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef"

  """
  @spec data_to_iodata(Data.t()) :: iodata()
  def data_to_iodata(data) do
    Data.to_iodata(data)
  end

  @doc """
  The fee a `transaction` paid for the `t:Explorer.Transaction.t/0` `gas`

  If the transaction is pending, then the fee will be a range of `unit`

      iex> Explorer.Chain.fee(
      ...>   %Explorer.Chain.Transaction{
      ...>     gas: Decimal.new(3),
      ...>     gas_price: %Explorer.Chain.Wei{value: Decimal.new(2)},
      ...>     gas_used: nil
      ...>   },
      ...>   :wei
      ...> )
      {:maximum, Decimal.new(6)}

  If the transaction has been confirmed in block, then the fee will be the actual fee paid in `unit` for the `gas_used`
  in the `transaction`.

      iex> Explorer.Chain.fee(
      ...>   %Explorer.Chain.Transaction{
      ...>     gas: Decimal.new(3),
      ...>     gas_price: %Explorer.Chain.Wei{value: Decimal.new(2)},
      ...>     gas_used: Decimal.new(2)
      ...>   },
      ...>   :wei
      ...> )
      {:actual, Decimal.new(4)}

  """
  @spec fee(%Transaction{gas_used: nil}, :ether | :gwei | :wei) :: {:maximum, Decimal.t()}
  def fee(%Transaction{gas: gas, gas_price: gas_price, gas_used: nil}, unit) do
    fee =
      gas_price
      |> Wei.to(unit)
      |> Decimal.mult(gas)

    {:maximum, fee}
  end

  @spec fee(%Transaction{gas_used: Decimal.t()}, :ether | :gwei | :wei) :: {:actual, Decimal.t()}
  def fee(%Transaction{gas_price: gas_price, gas_used: gas_used}, unit) do
    fee =
      gas_price
      |> Wei.to(unit)
      |> Decimal.mult(gas_used)

    {:actual, fee}
  end

  @doc """
  Checks to see if the chain is down indexing based on the transaction from the
  oldest block and the `fetch_internal_transactions` pending operation
  """
  @spec finished_indexing?() :: boolean()
  def finished_indexing? do
    json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)
    variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

    if variant == EthereumJSONRPC.Ganache || variant == EthereumJSONRPC.Arbitrum do
      true
    else
      with {:transactions_exist, true} <- {:transactions_exist, Repo.exists?(Transaction)},
           min_block_number when not is_nil(min_block_number) <- Repo.aggregate(Transaction, :min, :block_number) do
        query =
          from(
            b in Block,
            join: pending_ops in assoc(b, :pending_operations),
            where: pending_ops.fetch_internal_transactions,
            where: b.consensus and b.number == ^min_block_number
          )

        !Repo.exists?(query)
      else
        {:transactions_exist, false} -> true
        nil -> false
      end
    end
  end

  @doc """
  The `t:Explorer.Chain.Transaction.t/0` `gas_price` of the `transaction` in `unit`.
  """
  def gas_price(%Transaction{gas_price: gas_price}, unit) do
    Wei.to(gas_price, unit)
  end

  defp augment_celo_address(nil), do: {:error, :not_found}

  defp augment_celo_address(orig_address) do
    augmented =
      if Ecto.assoc_loaded?(orig_address.celo_delegator) and orig_address.celo_delegator != nil do
        orig_address
        |> Map.put(:celo_account, orig_address.celo_delegator.celo_account)
        |> Map.put(:celo_validator, orig_address.celo_delegator.celo_validator)
      else
        orig_address
      end

    {:ok, augmented}
  end

  @doc """
  Converts `t:Explorer.Chain.Address.t/0` `hash` to the `t:Explorer.Chain.Address.t/0` with that `hash`.

  Returns `{:ok, %Explorer.Chain.Address{}}` if found

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.create_address(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> {:ok, %Explorer.Chain.Address{hash: found_hash}} = Explorer.Chain.hash_to_address(hash)
      iex> found_hash == hash
      true

  Returns `{:error, :not_found}` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.hash_to_address(hash)
      {:error, :not_found}

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Address.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.Address.t/0` will not be included in the list.

  Optionally it also accepts a boolean to fetch the `has_decompiled_code?` virtual field or not

  """
  @spec hash_to_address(Hash.Address.t(), [necessity_by_association_option], boolean()) ::
          {:ok, Address.t()} | {:error, :not_found}
  def hash_to_address(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = hash,
        options \\ [
          necessity_by_association: %{
            :contracts_creation_internal_transaction => :optional,
            :names => :optional,
            :smart_contract => :optional,
            :token => :optional,
            :celo_account => :optional,
            :celo_delegator => :optional,
            :celo_signers => :optional,
            :celo_claims => :optional,
            :celo_members => :optional,
            [{:celo_delegator, :celo_account}] => :optional,
            [{:celo_delegator, :celo_validator}] => :optional,
            [{:celo_delegator, :celo_validator, :group_address}] => :optional,
            [{:celo_delegator, :celo_validator, :signer}] => :optional,
            [{:celo_delegator, :account_address}] => :optional,
            [{:celo_signers, :signer_address}] => :optional,
            [{:celo_claims, :celo_account}] => :optional,
            [{:celo_members, :validator_address}] => :optional,
            [{:celo_voters, :voter_address}] => :optional,
            [{:celo_voted, :group_address}] => :optional,
            [{:celo_voters, :group}] => :optional,
            [{:celo_voted, :group}] => :optional,
            :celo_validator => :optional,
            [{:celo_validator, :group_address}] => :optional,
            [{:celo_validator, :signer}] => :optional,
            :celo_validator_group => :optional,
            :contracts_creation_transaction => :optional
          }
        ],
        query_decompiled_code_flag \\ true
      ) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query =
      from(
        address in Address,
        where: address.hash == ^hash
      )

    address_result =
      query
      |> join_associations(necessity_by_association)
      |> with_decompiled_code_flag(hash, query_decompiled_code_flag)
      |> Repo.one()

    address_updated_result =
      case address_result do
        %{smart_contract: smart_contract} ->
          if smart_contract do
            address_result
          else
            address_verified_twin_contract =
              Chain.get_minimal_proxy_template(hash) ||
                Chain.get_address_verified_twin_contract(hash).verified_contract

            if address_verified_twin_contract do
              address_verified_twin_contract_updated =
                address_verified_twin_contract
                |> Map.put(:address_hash, hash)
                |> Map.put_new(:metadata_from_verified_twin, true)

              address_result
              |> Map.put(:smart_contract, address_verified_twin_contract_updated)
            else
              address_result
            end
          end

        _ ->
          address_result
      end

    augment_celo_address(address_updated_result)
  end

  def decompiled_code(address_hash, version) do
    query =
      from(contract in DecompiledSmartContract,
        where: contract.address_hash == ^address_hash and contract.decompiler_version == ^version
      )

    query
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      contract -> {:ok, contract.decompiled_source_code}
    end
  end

  @spec token_contract_address_from_token_name(String.t()) :: {:ok, Hash.Address.t()} | {:error, :not_found}
  def token_contract_address_from_token_name(name) when is_binary(name) do
    query =
      from(token in Token,
        where: ilike(token.symbol, ^name),
        or_where: ilike(token.name, ^name),
        select: token.contract_address_hash
      )

    query
    |> Repo.all()
    |> case do
      [] ->
        {:error, :not_found}

      hashes ->
        if Enum.count(hashes) == 1 do
          {:ok, List.first(hashes)}
        else
          {:error, :not_found}
        end
    end
  end

  def prepare_search_term(nil), do: {:some, ""}

  def prepare_search_term(string) do
    case Regex.scan(~r/[a-zA-Z0-9]+/, string) do
      [_ | _] = words ->
        term_final =
          words
          |> Enum.map(fn [word] -> word <> ":*" end)
          |> Enum.join(" & ")

        {:some, term_final}

      _ ->
        :none
    end
  end

  defp search_token_query(term) do
    from(token in Token,
      left_join: bridged in BridgedToken,
      on: token.contract_address_hash == bridged.home_token_contract_address_hash,
      where: fragment("to_tsvector(symbol || ' ' || name ) @@ to_tsquery(?)", ^term),
      select: %{
        address_hash: token.contract_address_hash,
        tx_hash: fragment("CAST(NULL AS bytea)"),
        block_hash: fragment("CAST(NULL AS bytea)"),
        foreign_token_hash: bridged.foreign_token_contract_address_hash,
        foreign_chain_id: bridged.foreign_chain_id,
        type: "token",
        name: token.name,
        symbol: token.symbol,
        holder_count: token.holder_count,
        inserted_at: token.inserted_at,
        block_number: 0
      }
    )
  end

  defp search_contract_query(term) do
    from(smart_contract in SmartContract,
      left_join: address in Address,
      on: smart_contract.address_hash == address.hash,
      where: fragment("to_tsvector(name ) @@ to_tsquery(?)", ^term),
      select: %{
        address_hash: smart_contract.address_hash,
        tx_hash: fragment("CAST(NULL AS bytea)"),
        block_hash: fragment("CAST(NULL AS bytea)"),
        foreign_token_hash: fragment("CAST(NULL AS bytea)"),
        foreign_chain_id: ^nil,
        type: "contract",
        name: smart_contract.name,
        symbol: ^nil,
        holder_count: ^nil,
        inserted_at: address.inserted_at,
        block_number: 0
      }
    )
  end

  defp search_address_query(term) do
    case Chain.string_to_address_hash(term) do
      {:ok, address_hash} ->
        from(address in Address,
          left_join: address_name in Address.Name,
          on: address.hash == address_name.address_hash,
          where: address.hash == ^address_hash,
          select: %{
            address_hash: address.hash,
            tx_hash: fragment("CAST(NULL AS bytea)"),
            block_hash: fragment("CAST(NULL AS bytea)"),
            foreign_token_hash: fragment("CAST(NULL AS bytea)"),
            foreign_chain_id: ^nil,
            type: "address",
            name: address_name.name,
            symbol: ^nil,
            holder_count: ^nil,
            inserted_at: address.inserted_at,
            block_number: 0
          }
        )

      _ ->
        nil
    end
  end

  defp search_tx_query(term) do
    case Chain.string_to_transaction_hash(term) do
      {:ok, tx_hash} ->
        from(transaction in Transaction,
          where: transaction.hash == ^tx_hash,
          select: %{
            address_hash: fragment("CAST(NULL AS bytea)"),
            tx_hash: transaction.hash,
            block_hash: fragment("CAST(NULL AS bytea)"),
            foreign_token_hash: fragment("CAST(NULL AS bytea)"),
            foreign_chain_id: ^nil,
            type: "transaction",
            name: ^nil,
            symbol: ^nil,
            holder_count: ^nil,
            inserted_at: transaction.inserted_at,
            block_number: 0
          }
        )

      _ ->
        nil
    end
  end

  defp search_block_query(term) do
    case Chain.string_to_block_hash(term) do
      {:ok, block_hash} ->
        from(block in Block,
          where: block.hash == ^block_hash,
          select: %{
            address_hash: fragment("CAST(NULL AS bytea)"),
            tx_hash: fragment("CAST(NULL AS bytea)"),
            block_hash: block.hash,
            foreign_token_hash: fragment("CAST(NULL AS bytea)"),
            foreign_chain_id: ^nil,
            type: "block",
            name: ^nil,
            symbol: ^nil,
            holder_count: ^nil,
            inserted_at: block.inserted_at,
            block_number: block.number
          }
        )

      _ ->
        case Integer.parse(term) do
          {block_number, _} ->
            from(block in Block,
              where: block.number == ^block_number,
              select: %{
                address_hash: fragment("CAST(NULL AS bytea)"),
                tx_hash: fragment("CAST(NULL AS bytea)"),
                block_hash: block.hash,
                foreign_token_hash: fragment("CAST(NULL AS bytea)"),
                foreign_chain_id: ^nil,
                type: "block",
                name: ^nil,
                symbol: ^nil,
                holder_count: ^nil,
                inserted_at: block.inserted_at,
                block_number: block.number
              }
            )

          _ ->
            nil
        end
    end
  end

  def joint_search(paging_options, offset, string) do
    case prepare_search_term(string) do
      {:some, term} ->
        tokens_query = search_token_query(term)
        contracts_query = search_contract_query(term)
        tx_query = search_tx_query(string)
        address_query = search_address_query(string)
        block_query = search_block_query(string)

        basic_query =
          from(
            tokens in subquery(tokens_query),
            union: ^contracts_query
          )

        query =
          cond do
            address_query ->
              basic_query
              |> union(^address_query)

            tx_query ->
              basic_query
              |> union(^tx_query)
              |> union(^block_query)

            block_query ->
              basic_query
              |> union(^block_query)

            true ->
              basic_query
          end

        ordered_query =
          from(items in subquery(query),
            order_by: [desc_nulls_last: items.holder_count, asc: items.name, desc: items.inserted_at],
            limit: ^paging_options.page_size,
            offset: ^offset
          )

        paginated_ordered_query =
          ordered_query
          |> page_search_results(paging_options)

        search_results = Repo.all(paginated_ordered_query)

        search_results
        |> Enum.map(fn result ->
          result_checksummed_address_hash =
            if result.address_hash do
              result
              |> Map.put(:address_hash, Address.checksum(result.address_hash))
            else
              result
            end

          result_checksummed =
            if result_checksummed_address_hash.foreign_token_hash do
              result_checksummed_address_hash
              |> Map.put(:foreign_token_hash, Address.checksum(result_checksummed_address_hash.foreign_token_hash))
            else
              result_checksummed_address_hash
            end

          result_checksummed
        end)

      _ ->
        []
    end
  end

  @spec search_token(String.t()) :: [Token.t()]
  def search_token(string) do
    case prepare_search_term(string) do
      {:some, term} ->
        query =
          from(token in Token,
            where: fragment("to_tsvector(symbol || ' ' || name ) @@ to_tsquery(?)", ^term),
            select: %{
              link: token.contract_address_hash,
              symbol: token.symbol,
              name: token.name,
              holder_count: token.holder_count,
              type: "token"
            },
            order_by: [desc: token.holder_count]
          )

        Repo.all(query)

      _ ->
        []
    end
  end

  @spec search_contract(String.t()) :: [SmartContract.t()]
  def search_contract(string) do
    case prepare_search_term(string) do
      {:some, term} ->
        query =
          from(smart_contract in SmartContract,
            left_join: address in Address,
            on: smart_contract.address_hash == address.hash,
            where: fragment("to_tsvector(name ) @@ to_tsquery(?)", ^term),
            select: %{
              link: smart_contract.address_hash,
              name: smart_contract.name,
              inserted_at: address.inserted_at,
              type: "contract"
            },
            order_by: [desc: smart_contract.inserted_at]
          )

        Repo.all(query)

      _ ->
        []
    end
  end

  def search_tx(term) do
    case Chain.string_to_transaction_hash(term) do
      {:ok, tx_hash} ->
        query =
          from(transaction in Transaction,
            where: transaction.hash == ^tx_hash,
            select: %{
              link: transaction.hash,
              type: "transaction"
            }
          )

        Repo.all(query)

      _ ->
        []
    end
  end

  def search_address(term) do
    case Chain.string_to_address_hash(term) do
      {:ok, address_hash} ->
        query =
          from(address in Address,
            left_join: address_name in Address.Name,
            on: address.hash == address_name.address_hash,
            where: address.hash == ^address_hash,
            select: %{
              name: address_name.name,
              link: address.hash,
              type: "address"
            }
          )

        Repo.all(query)

      _ ->
        []
    end
  end

  def search_block(term) do
    case Chain.string_to_block_hash(term) do
      {:ok, block_hash} ->
        query =
          from(block in Block,
            where: block.hash == ^block_hash,
            select: %{
              link: block.hash,
              block_number: block.number,
              type: "block"
            }
          )

        Repo.all(query)

      _ ->
        case Integer.parse(term) do
          {block_number, _} ->
            query =
              from(block in Block,
                where: block.number == ^block_number,
                select: %{
                  link: block.hash,
                  block_number: block.number,
                  type: "block"
                }
              )

            Repo.all(query)

          _ ->
            []
        end
    end
  end

  @doc """
  Converts `t:Explorer.Chain.Address.t/0` `hash` to the `t:Explorer.Chain.Address.t/0` with that `hash`.

  Returns `{:ok, %Explorer.Chain.Address{}}` if found

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.create_address(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> {:ok, %Explorer.Chain.Address{hash: found_hash}} = Explorer.Chain.hash_to_address(hash)
      iex> found_hash == hash
      true

  Returns `{:error, address}` if not found but created an address

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.create_address(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> {:ok, %Explorer.Chain.Address{hash: found_hash}} = Explorer.Chain.hash_to_address(hash)
      iex> found_hash == hash
      true


  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Address.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.Address.t/0` will not be included in the list.

  Optionally it also accepts a boolean to fetch the `has_decompiled_code?` virtual field or not

  """
  @spec find_or_insert_address_from_hash(Hash.Address.t(), [necessity_by_association_option], boolean()) ::
          {:ok, Address.t()}
  def find_or_insert_address_from_hash(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = hash,
        options \\ [
          necessity_by_association: %{
            :contracts_creation_internal_transaction => :optional,
            :names => :optional,
            :smart_contract => :optional,
            :token => :optional,
            :celo_account => :optional,
            :celo_delegator => :optional,
            [{:celo_delegator, :celo_account}] => :optional,
            :contracts_creation_transaction => :optional
          }
        ],
        query_decompiled_code_flag \\ true
      ) do
    case hash_to_address(hash, options, query_decompiled_code_flag) do
      {:ok, address} ->
        {:ok, address}

      {:error, :not_found} ->
        create_address(%{hash: to_string(hash)})
        hash_to_address(hash, options, query_decompiled_code_flag)
    end
  end

  @doc """
  Converts list of `t:Explorer.Chain.Address.t/0` `hash` to the `t:Explorer.Chain.Address.t/0` with that `hash`.

  Returns `[%Explorer.Chain.Address{}]}` if found

  """
  @spec hashes_to_addresses([Hash.Address.t()]) :: [Address.t()]
  def hashes_to_addresses(hashes) when is_list(hashes) do
    query =
      from(
        address in Address,
        where: address.hash in ^hashes,
        # https://stackoverflow.com/a/29598910/470451
        order_by: fragment("array_position(?, ?)", type(^hashes, {:array, Hash.Address}), address.hash)
      )

    Repo.all(query)
  end

  def get_elected_validators(num) do
    query =
      from(
        address in Address,
        join: sel in CeloValidatorHistory,
        on: sel.address == address.hash,
        where: sel.block_number == ^num,
        select_merge: %{
          online: sel.online
        }
      )

    Repo.all(query)
  end

  @doc """
  Returns the balance of the given address and block combination.

  Returns `{:error, :not_found}` if there is no address by that hash present.
  Returns `{:error, :no_balance}` if there is no balance for that address at that block.
  """
  @spec get_balance_as_of_block(Hash.Address.t(), Block.block_number() | :earliest | :latest | :pending) ::
          {:ok, Wei.t()} | {:error, :no_balance} | {:error, :not_found}
  def get_balance_as_of_block(address, block) when is_integer(block) do
    coin_balance_query =
      from(coin_balance in CoinBalance,
        where: coin_balance.address_hash == ^address,
        where: not is_nil(coin_balance.value),
        where: coin_balance.block_number <= ^block,
        order_by: [desc: coin_balance.block_number],
        limit: 1,
        select: coin_balance.value
      )

    case Repo.one(coin_balance_query) do
      nil -> {:error, :not_found}
      coin_balance -> {:ok, coin_balance}
    end
  end

  def get_balance_as_of_block(address, :latest) do
    case max_consensus_block_number() do
      {:ok, latest_block_number} ->
        get_balance_as_of_block(address, latest_block_number)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def get_balance_as_of_block(address, :earliest) do
    query =
      from(coin_balance in CoinBalance,
        where: coin_balance.address_hash == ^address,
        where: not is_nil(coin_balance.value),
        where: coin_balance.block_number == 0,
        limit: 1,
        select: coin_balance.value
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      coin_balance -> {:ok, coin_balance}
    end
  end

  def get_balance_as_of_block(address, :pending) do
    query =
      case max_consensus_block_number() do
        {:ok, latest_block_number} ->
          from(coin_balance in CoinBalance,
            where: coin_balance.address_hash == ^address,
            where: not is_nil(coin_balance.value),
            where: coin_balance.block_number > ^latest_block_number,
            order_by: [desc: coin_balance.block_number],
            limit: 1,
            select: coin_balance.value
          )

        {:error, :not_found} ->
          from(coin_balance in CoinBalance,
            where: coin_balance.address_hash == ^address,
            where: not is_nil(coin_balance.value),
            order_by: [desc: coin_balance.block_number],
            limit: 1,
            select: coin_balance.value
          )
      end

    case Repo.one(query) do
      nil -> {:error, :not_found}
      coin_balance -> {:ok, coin_balance}
    end
  end

  @spec list_ordered_addresses(non_neg_integer(), non_neg_integer()) :: [Address.t()]
  def list_ordered_addresses(offset, limit) do
    query =
      from(
        address in Address,
        order_by: [asc: address.inserted_at],
        offset: ^offset,
        limit: ^limit
      )

    Repo.all(query)
  end

  @doc """
  Finds an `t:Explorer.Chain.Address.t/0` that has the provided `t:Explorer.Chain.Address.t/0` `hash` and a contract.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Address.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.Address.t/0` will not be included in the list.

  Optionally it also accepts a boolean to fetch the `has_decompiled_code?` virtual field or not

  """
  @spec find_contract_address(Hash.Address.t(), [necessity_by_association_option], boolean()) ::
          {:ok, Address.t()} | {:error, :not_found}
  def find_contract_address(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = hash,
        options \\ [],
        query_decompiled_code_flag \\ false
      ) do
    necessity_by_association =
      options
      |> Keyword.get(:necessity_by_association, %{})
      |> Map.merge(%{
        smart_contract_additional_sources: :optional,
        smart_contract: :optional
      })

    query =
      from(
        address in Address,
        where: address.hash == ^hash and not is_nil(address.contract_code)
      )

    address_result =
      query
      |> join_associations(necessity_by_association)
      |> with_decompiled_code_flag(hash, query_decompiled_code_flag)
      |> Repo.one()

    address_updated_result =
      case address_result do
        %{smart_contract: smart_contract} ->
          if smart_contract do
            address_result
          else
            address_verified_twin_contract =
              Chain.get_minimal_proxy_template(hash) ||
                Chain.get_address_verified_twin_contract(hash).verified_contract

            if address_verified_twin_contract do
              address_verified_twin_contract_updated =
                address_verified_twin_contract
                |> Map.put(:address_hash, hash)
                |> Map.put_new(:metadata_from_verified_twin, true)

              address_result
              |> Map.put(:smart_contract, address_verified_twin_contract_updated)
            else
              address_result
            end
          end

        _ ->
          address_result
      end

    address_updated_result
    |> case do
      nil -> {:error, :not_found}
      address -> {:ok, address}
    end
  end

  @spec find_decompiled_contract_address(Hash.Address.t()) :: {:ok, Address.t()} | {:error, :not_found}
  def find_decompiled_contract_address(%Hash{byte_count: unquote(Hash.Address.byte_count())} = hash) do
    query =
      from(
        address in Address,
        preload: [
          :contracts_creation_internal_transaction,
          :names,
          :smart_contract,
          :token,
          :contracts_creation_transaction,
          :decompiled_smart_contracts
        ],
        where: address.hash == ^hash
      )

    address = Repo.one(query)

    if address do
      {:ok, address}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Converts `t:Explorer.Chain.Block.t/0` `hash` to the `t:Explorer.Chain.Block.t/0` with that `hash`.

  Unlike `number_to_block/1`, both consensus and non-consensus blocks can be returned when looked up by `hash`.

  Returns `{:ok, %Explorer.Chain.Block{}}` if found

      iex> %Block{hash: hash} = insert(:block, consensus: false)
      iex> {:ok, %Explorer.Chain.Block{hash: found_hash}} = Explorer.Chain.hash_to_block(hash)
      iex> found_hash == hash
      true

  Returns `{:error, :not_found}` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_block_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.hash_to_block(hash)
      {:error, :not_found}

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Block.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Block.t/0` will not be included in the page `entries`.

  """
  @spec hash_to_block(Hash.Full.t(), [necessity_by_association_option]) :: {:ok, Block.t()} | {:error, :not_found}
  def hash_to_block(%Hash{byte_count: unquote(Hash.Full.byte_count())} = hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Block
    |> where(hash: ^hash)
    |> join_associations(necessity_by_association)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      block ->
        {:ok, block}
    end
  end

  @doc """
  Converts the `Explorer.Chain.Hash.t:t/0` to `iodata` representation that can be written efficiently to users.

      iex> %Explorer.Chain.Hash{
      ...>   byte_count: 32,
      ...>   bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b ::
      ...>            big-integer-size(32)-unit(8)>>
      ...> } |>
      ...> Explorer.Chain.hash_to_iodata() |>
      ...> IO.iodata_to_binary()
      "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"

  Always pads number, so that it is a valid format for casting.

      iex> %Explorer.Chain.Hash{
      ...>   byte_count: 32,
      ...>   bytes: <<0x1234567890abcdef :: big-integer-size(32)-unit(8)>>
      ...> } |>
      ...> Explorer.Chain.hash_to_iodata() |>
      ...> IO.iodata_to_binary()
      "0x0000000000000000000000000000000000000000000000001234567890abcdef"

  """
  @spec hash_to_iodata(Hash.t()) :: iodata()
  def hash_to_iodata(hash) do
    Hash.to_iodata(hash)
  end

  @doc """
  Converts `t:Explorer.Chain.Transaction.t/0` `hash` to the `t:Explorer.Chain.Transaction.t/0` with that `hash`.

  Returns `{:ok, %Explorer.Chain.Transaction{}}` if found

      iex> %Transaction{hash: hash} = insert(:transaction)
      iex> {:ok, %Explorer.Chain.Transaction{hash: found_hash}} = Explorer.Chain.hash_to_transaction(hash)
      iex> found_hash == hash
      true

  Returns `{:error, :not_found}` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_transaction_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.hash_to_transaction(hash)
      {:error, :not_found}

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
  """
  @spec hash_to_transaction(Hash.Full.t(), [necessity_by_association_option]) ::
          {:ok, Transaction.t()} | {:error, :not_found}
  def hash_to_transaction(
        %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash,
        options \\ []
      )
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Transaction
    |> where(hash: ^hash)
    |> join_associations(necessity_by_association)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      transaction ->
        {:ok, transaction}
    end
  end

  @doc """
  Converts list of `t:Explorer.Chain.Transaction.t/0` `hashes` to the list of `t:Explorer.Chain.Transaction.t/0`s for
  those `hashes`.

  Returns list of `%Explorer.Chain.Transaction{}`s if found

      iex> [%Transaction{hash: hash1}, %Transaction{hash: hash2}] = insert_list(2, :transaction)
      iex> [%Explorer.Chain.Transaction{hash: found_hash1}, %Explorer.Chain.Transaction{hash: found_hash2}] =
      ...>   Explorer.Chain.hashes_to_transactions([hash1, hash2])
      iex> found_hash1 in [hash1, hash2]
      true
      iex> found_hash2 in [hash1, hash2]
      true

  Returns `[]` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_transaction_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.hashes_to_transactions([hash])
      []

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
  """
  @spec hashes_to_transactions([Hash.Full.t()], [necessity_by_association_option]) :: [Transaction.t()] | []
  def hashes_to_transactions(hashes, options \\ []) when is_list(hashes) and is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    fetch_transactions()
    |> where([transaction], transaction.hash in ^hashes)
    |> join_associations(necessity_by_association)
    |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
    |> Repo.all()
  end

  @doc """
  Bulk insert all data stored in the `Explorer`.

  See `Explorer.Chain.Import.all/1` for options and returns.
  """
  @spec import(Import.all_options()) :: Import.all_result()
  def import(options) do
    Import.all(options)
  end

  @doc """
  The percentage of indexed blocks on the chain.

      iex> for index <- 5..9 do
      ...>   insert(:block, number: index)
      ...>   Process.sleep(200)
      ...> end
      iex> Explorer.Chain.indexed_ratio()
      Decimal.new(1, 50, -2)

  If there are no blocks, the percentage is 0.

      iex> Explorer.Chain.indexed_ratio()
      Decimal.new(0)

  """
  @spec indexed_ratio() :: Decimal.t()
  def indexed_ratio do
    %{min: min, max: max} = BlockNumber.get_all()

    case {min, max} do
      {0, 0} ->
        Decimal.new(0)

      _ ->
        result = Decimal.div(max - min + 1, max + 1)

        Decimal.round(result, 2, :down)
    end
  end

  @spec fetch_min_block_number() :: non_neg_integer
  def fetch_min_block_number do
    query =
      from(block in Block,
        select: block.number,
        where: block.consensus == true,
        order_by: [asc: block.number],
        limit: 1
      )

    Repo.one(query) || 0
  rescue
    _ ->
      0
  end

  @spec fetch_max_block_number() :: non_neg_integer
  def fetch_max_block_number do
    query =
      from(block in Block,
        select: block.number,
        where: block.consensus == true,
        order_by: [desc: block.number],
        limit: 1
      )

    Repo.one(query) || 0
  rescue
    _ ->
      0
  end

  @doc """
  Fetches count of last n blocks, last block timestamp, last block number and average gas used in the last minute.
  Using a single method to fetch and calculate these values for performance reasons (only 2 queries used).
  """
  @spec metrics_fetcher(integer | nil) ::
          {non_neg_integer, non_neg_integer, non_neg_integer, float}
  def metrics_fetcher(n) do
    last_block_number = fetch_max_block_number()

    if last_block_number == 0 do
      {0, 0, 0, 0}
    else
      range_start = last_block_number - n + 1

      last_n_blocks_result =
        SQL.query!(
          Repo,
          """
          SELECT
          COUNT(*) AS last_n_blocks_count,
          CAST(EXTRACT(EPOCH FROM (DATE_TRUNC('second', NOW()::timestamp) - MAX(timestamp))) AS INTEGER) AS last_block_age,
          AVG((gas_used/gas_limit)*100) AS average_gas_used
          FROM blocks
          WHERE number BETWEEN $1 AND $2;
          """,
          [range_start, last_block_number]
        )

      {last_n_blocks_count, last_block_age, average_gas_used} =
        case Map.fetch(last_n_blocks_result, :rows) do
          {:ok, [[last_n_blocks_count, last_block_age, average_gas_used]]} ->
            {last_n_blocks_count, last_block_age, average_gas_used}

          _ ->
            0
        end

      {last_n_blocks_count, last_block_age, last_block_number, Decimal.to_float(average_gas_used)}
    end
  end

  @spec fetch_count_consensus_block() :: non_neg_integer
  def fetch_count_consensus_block do
    query =
      from(block in Block,
        select: count(block.hash),
        where: block.consensus == true
      )

    Repo.one!(query, timeout: :infinity) || 0
  end

  def fetch_block_by_hash(block_hash) do
    Repo.get(Block, block_hash)
  end

  @spec fetch_sum_coin_total_supply_minus_burnt() :: non_neg_integer
  def fetch_sum_coin_total_supply_minus_burnt do
    {:ok, burn_address_hash} = Chain.string_to_address_hash(@burn_address_hash_str)

    query =
      from(
        a0 in Address,
        select: fragment("SUM(a0.fetched_coin_balance)"),
        where: a0.hash != ^burn_address_hash,
        where: a0.fetched_coin_balance > ^0
      )

    Repo.one!(query, timeout: :infinity) || 0
  end

  @spec fetch_sum_coin_total_supply() :: non_neg_integer
  def fetch_sum_coin_total_supply do
    query =
      from(
        a0 in Address,
        select: fragment("SUM(a0.fetched_coin_balance)"),
        where: a0.fetched_coin_balance > ^0
      )

    Repo.one!(query, timeout: :infinity) || 0
  end

  @spec fetch_sum_gas_used() :: non_neg_integer
  def fetch_sum_gas_used do
    query =
      from(
        t0 in Transaction,
        select: fragment("SUM(t0.gas_used)")
      )

    Repo.one!(query, timeout: :infinity) || 0
  end

  @doc """
  The number of `t:Explorer.Chain.InternalTransaction.t/0`.

      iex> transaction = :transaction |> insert() |> with_block()
      iex> insert(:internal_transaction, index: 0, transaction: transaction, block_hash: transaction.block_hash, block_index: 0)
      iex> Explorer.Chain.internal_transaction_count()
      1

  If there are none, the count is `0`.

      iex> Explorer.Chain.internal_transaction_count()
      0

  """
  def internal_transaction_count do
    Repo.aggregate(InternalTransaction.where_nonpending_block(), :count, :transaction_hash)
  end

  @doc """
  Finds all `t:Explorer.Chain.Transaction.t/0` in the `t:Explorer.Chain.Block.t/0`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
        `:required`, and the `t:Explorer.Chain.Block.t/0` has no associated record for that association, then the
        `t:Explorer.Chain.Block.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number}`). Results will be the internal
      transactions older than the `block_number` that are passed.
    * ':block_type' - use to filter by type of block; Uncle`, `Reorg`, or `Block` (default).

  """
  @spec list_blocks([paging_options | necessity_by_association_option]) :: [Block.t()]
  def list_blocks(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options) || @default_paging_options
    block_type = Keyword.get(options, :block_type, "Block")

    cond do
      block_type == "Block" && !paging_options.key ->
        block_from_cache(block_type, paging_options, necessity_by_association)

      block_type == "Uncle" && !paging_options.key ->
        uncles_from_cache(block_type, paging_options, necessity_by_association)

      true ->
        fetch_blocks(block_type, paging_options, necessity_by_association)
    end
  end

  defp block_from_cache(block_type, paging_options, necessity_by_association) do
    case Blocks.take_enough(paging_options.page_size) do
      nil ->
        elements = fetch_blocks(block_type, paging_options, necessity_by_association)

        Blocks.update(elements)

        elements

      blocks ->
        blocks
    end
  end

  def uncles_from_cache(block_type, paging_options, necessity_by_association) do
    case Uncles.take_enough(paging_options.page_size) do
      nil ->
        elements = fetch_blocks(block_type, paging_options, necessity_by_association)

        Uncles.update(elements)

        elements

      blocks ->
        blocks
    end
  end

  defp fetch_blocks(block_type, paging_options, necessity_by_association) do
    Block
    |> Block.block_type_filter(block_type)
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  @doc """
  Map `block_number`s to their `t:Explorer.Chain.Block.t/0` `hash` `t:Explorer.Chain.Hash.Full.t/0`.

  Does not include non-consensus blocks.

      iex> block = insert(:block, consensus: false)
      iex> Explorer.Chain.block_hash_by_number([block.number])
      %{}

  """
  @spec block_hash_by_number([Block.block_number()]) :: %{Block.block_number() => Hash.Full.t()}
  def block_hash_by_number(block_numbers) when is_list(block_numbers) do
    query =
      from(block in Block,
        where: block.consensus == true and block.number in ^block_numbers,
        select: {block.number, block.hash}
      )

    query
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Lists the top `t:Explorer.Chain.Address.t/0`'s' in descending order based on coin balance and address hash.

  """
  @spec list_top_addresses :: [{Address.t(), non_neg_integer()}]
  def list_top_addresses(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    if is_nil(paging_options.key) do
      paging_options.page_size
      |> Accounts.take_enough()
      |> case do
        nil ->
          accounts_with_n = fetch_top_addresses(paging_options)

          accounts_with_n
          |> Enum.map(fn {address, _n} -> address end)
          |> Accounts.update()

          accounts_with_n

        accounts ->
          Enum.map(
            accounts,
            &{&1,
             if is_nil(&1.nonce) do
               0
             else
               &1.nonce + 1
             end}
          )
      end
    else
      fetch_top_addresses(paging_options)
    end
  end

  defp fetch_top_addresses(paging_options) do
    base_query =
      from(a in Address,
        where: a.fetched_coin_balance > ^0,
        order_by: [desc: a.fetched_coin_balance, asc: a.hash],
        preload: [:names],
        select: {a, fragment("coalesce(1 + ?, 0)", a.nonce)}
      )

    base_query
    |> page_addresses(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.all()
  end

  @doc """
  Lists the top `t:Explorer.Chain.Token.t/0`'s'.

  """
  @spec list_top_tokens(String.t()) :: [{Token.t(), non_neg_integer()}]
  def list_top_tokens(filter, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    fetch_top_tokens(filter, paging_options)
  end

  @spec list_top_bridged_tokens(atom(), String.t(), [paging_options | necessity_by_association_option]) :: [
          {Token.t(), non_neg_integer()}
        ]
  def list_top_bridged_tokens(destination, filter, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    fetch_top_bridged_tokens(destination, paging_options, filter)
  end

  defp fetch_top_tokens(filter, paging_options) do
    base_query =
      from(t in Token,
        where: t.total_supply > ^0,
        order_by: [desc_nulls_last: t.holder_count, asc: t.name],
        preload: [:contract_address]
      )

    base_query_with_paging =
      base_query
      |> page_tokens(paging_options)
      |> limit(^paging_options.page_size)

    case prepare_search_term(filter) do
      {:some, term} ->
        query =
          if String.length(term) > 0 do
            base_query_with_paging
            |> where(fragment("to_tsvector('english', symbol || ' ' || name ) @@ to_tsquery(?)", ^term))
          else
            base_query_with_paging
          end

        query |> Repo.all()

      _ ->
        []
    end
  end

  defp fetch_top_bridged_tokens(destination, paging_options, filter) do
    chain_id = translate_destination_to_chain_id(destination)

    bridged_tokens_query =
      from(bt in BridgedToken,
        select: bt,
        where: bt.foreign_chain_id == ^chain_id
      )

    base_query =
      from(t in Token,
        right_join: bt in subquery(bridged_tokens_query),
        on: t.contract_address_hash == bt.home_token_contract_address_hash,
        where: t.total_supply > ^0,
        where: t.bridged,
        order_by: [desc: t.holder_count, asc: t.name],
        select: [t, bt],
        preload: [:contract_address]
      )

    base_query_with_paging =
      base_query
      |> page_tokens(paging_options)
      |> limit(^paging_options.page_size)

    case prepare_search_term(filter) do
      {:some, term} ->
        query =
          if String.length(term) > 0 do
            base_query_with_paging
            |> where(fragment("to_tsvector('english', symbol || ' ' || name ) @@ to_tsquery(?)", ^term))
          else
            base_query_with_paging
          end

        query |> Repo.all()

      _ ->
        []
    end
  end

  defp translate_destination_to_chain_id(destination) do
    case destination do
      :eth -> 1
      :bsc -> 56
      _ -> 1
    end
  end

  @doc """
  Calls `reducer` on a stream of `t:Explorer.Chain.Block.t/0` without `t:Explorer.Chain.Block.Reward.t/0`.
  """
  def stream_blocks_without_rewards(initial, reducer) when is_function(reducer, 2) do
    Block.blocks_without_reward_query()
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Finds all transactions of a certain block number
  """
  def get_transactions_of_block_number(block_number) do
    block_number
    |> Transaction.transactions_with_block_number()
    |> Repo.all()
  end

  @doc """
  Finds all Blocks validated by the address with the given hash.

    ## Options
      * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
          `:required`, and the `t:Explorer.Chain.Block.t/0` has no associated record for that association, then the
          `t:Explorer.Chain.Block.t/0` will not be included in the page `entries`.
      * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
        `:key` (a tuple of the lowest/oldest `{block_number}`) and. Results will be the internal
        transactions older than the `block_number` that are passed.

  Returns all blocks validated by the address given.
  """
  @spec get_blocks_validated_by_address(
          [paging_options | necessity_by_association_option],
          Hash.Address.t()
        ) :: [Block.t()]
  def get_blocks_validated_by_address(options \\ [], address_hash) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    Block
    |> join_associations(necessity_by_association)
    |> where(miner_hash: ^address_hash)
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> Repo.all()
  end

  def get_blocks_handled_by_address(options \\ [], address_hash) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    query =
      from(b in Block,
        join: h in CeloValidatorHistory,
        where: b.number == h.block_number,
        where: h.address == ^address_hash,
        select: b
      )

    online_query =
      from(
        h in CeloValidatorHistory,
        where: h.address == ^address_hash,
        select: h.online
      )

    query
    |> join_associations(necessity_by_association)
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> preload(online: ^online_query)
    |> Repo.all()
  end

  def get_downtime_by_address(options \\ [], address_hash) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    query =
      from(b in Block,
        join: h in CeloValidatorHistory,
        where: b.number == h.block_number,
        where: h.address == ^address_hash,
        where: h.online == false,
        select: b
      )

    online_query =
      from(
        h in CeloValidatorHistory,
        where: h.address == ^address_hash,
        select: h.online
      )

    query
    |> join_associations(necessity_by_association)
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> preload(online: ^online_query)
    |> Repo.all()
  end

  def check_if_validated_blocks_at_address(address_hash) do
    Repo.exists?(from(b in Block, where: b.miner_hash == ^address_hash))
  end

  def check_if_logs_at_address(address_hash) do
    Repo.exists?(from(l in Log, where: l.address_hash == ^address_hash))
  end

  def check_if_internal_transactions_at_address(address_hash) do
    internal_transactions_exists_by_created_contract_address_hash =
      Repo.exists?(from(it in InternalTransaction, where: it.created_contract_address_hash == ^address_hash))

    internal_transactions_exists_by_from_address_hash =
      Repo.exists?(from(it in InternalTransaction, where: it.from_address_hash == ^address_hash))

    internal_transactions_exists_by_to_address_hash =
      Repo.exists?(from(it in InternalTransaction, where: it.to_address_hash == ^address_hash))

    internal_transactions_exists_by_created_contract_address_hash || internal_transactions_exists_by_from_address_hash ||
      internal_transactions_exists_by_to_address_hash
  end

  def check_if_token_transfers_at_address(address_hash) do
    token_transfers_exists_by_from_address_hash =
      Repo.exists?(from(tt in TokenTransfer, where: tt.from_address_hash == ^address_hash))

    token_transfers_exists_by_to_address_hash =
      Repo.exists?(from(tt in TokenTransfer, where: tt.to_address_hash == ^address_hash))

    token_transfers_exists_by_from_address_hash ||
      token_transfers_exists_by_to_address_hash
  end

  def check_if_tokens_at_address(address_hash) do
    Repo.exists?(
      from(
        tb in CurrentTokenBalance,
        where: tb.address_hash == ^address_hash,
        where: tb.value > 0
      )
    )
  end

  @doc """
  Counts all of the block validations and groups by the `miner_hash`.
  """
  def each_address_block_validation_count(fun) when is_function(fun, 1) do
    query =
      from(
        b in Block,
        join: addr in Address,
        where: b.miner_hash == addr.hash,
        select: {b.miner_hash, count(b.miner_hash)},
        group_by: b.miner_hash
      )

    Repo.stream_each(query, fun)
  end

  @doc """
  Counts the number of `t:Explorer.Chain.Block.t/0` validated by the address with the given `hash`.
  """
  @spec address_to_validation_count(Hash.Address.t()) :: non_neg_integer()
  def address_to_validation_count(hash) do
    query = from(block in Block, where: block.miner_hash == ^hash, select: fragment("COUNT(*)"))

    Repo.one(query)
  end

  @spec address_to_transaction_count(Address.t()) :: non_neg_integer()
  def address_to_transaction_count(address) do
    if contract?(address) do
      incoming_transaction_count = address_to_incoming_transaction_count(address.hash)

      if incoming_transaction_count == 0 do
        total_transactions_sent_by_address(address.hash)
      else
        incoming_transaction_count
      end
    else
      total_transactions_sent_by_address(address.hash)
    end
  end

  @spec address_to_token_transfer_count(Address.t()) :: non_neg_integer()
  def address_to_token_transfer_count(address) do
    query =
      from(
        token_transfer in TokenTransfer,
        where: token_transfer.to_address_hash == ^address.hash,
        or_where: token_transfer.from_address_hash == ^address.hash
      )

    Repo.aggregate(query, :count, timeout: :infinity)
  end

  @spec address_to_gas_usage_count(Address.t()) :: non_neg_integer()
  def address_to_gas_usage_count(address) do
    if contract?(address) do
      incoming_transaction_gas_usage = address_to_incoming_transaction_gas_usage(address.hash)

      if incoming_transaction_gas_usage == 0 do
        address_to_outcoming_transaction_gas_usage(address.hash)
      else
        incoming_transaction_gas_usage
      end
    else
      address_to_outcoming_transaction_gas_usage(address.hash)
    end
  end

  @doc """
  Return the balance in usd corresponding to this token. Return nil if the usd_value of the token is not present.
  """
  def balance_in_usd(%{token: %{usd_value: nil}}) do
    nil
  end

  def balance_in_usd(token_balance) do
    tokens = CurrencyHelpers.divide_decimals(token_balance.value, token_balance.token.decimals)
    price = token_balance.token.usd_value
    Decimal.mult(tokens, price)
  end

  def address_tokens_usd_sum(token_balances) do
    token_balances
    |> Enum.reduce(Decimal.new(0), fn {token_balance, _, _}, acc ->
      if token_balance.value && token_balance.token.usd_value do
        Decimal.add(acc, balance_in_usd(token_balance))
      else
        acc
      end
    end)
  end

  defp contract?(%{contract_code: nil}), do: false

  defp contract?(%{contract_code: _}), do: true

  @doc """
  Returns a stream of unfetched `t:Explorer.Chain.Address.CoinBalance.t/0`.

  When there are addresses, the `reducer` is called for each `t:Explorer.Chain.Address.t/0` `hash` and all
  `t:Explorer.Chain.Block.t/0` `block_number` that address is mentioned.

  | Address Hash Schema                        | Address Hash Field              | Block Number Schema                | Block Number Field |
  |--------------------------------------------|---------------------------------|------------------------------------|--------------------|
  | `t:Explorer.Chain.Block.t/0`               | `miner_hash`                    | `t:Explorer.Chain.Block.t/0`       | `number`           |
  | `t:Explorer.Chain.Transaction.t/0`         | `from_address_hash`             | `t:Explorer.Chain.Transaction.t/0` | `block_number`     |
  | `t:Explorer.Chain.Transaction.t/0`         | `to_address_hash`               | `t:Explorer.Chain.Transaction.t/0` | `block_number`     |
  | `t:Explorer.Chain.Log.t/0`                 | `address_hash`                  | `t:Explorer.Chain.Transaction.t/0` | `block_number`     |
  | `t:Explorer.Chain.InternalTransaction.t/0` | `created_contract_address_hash` | `t:Explorer.Chain.Transaction.t/0` | `block_number`     |
  | `t:Explorer.Chain.InternalTransaction.t/0` | `from_address_hash`             | `t:Explorer.Chain.Transaction.t/0` | `block_number`     |
  | `t:Explorer.Chain.InternalTransaction.t/0` | `to_address_hash`               | `t:Explorer.Chain.Transaction.t/0` | `block_number`     |

  Pending `t:Explorer.Chain.Transaction.t/0` `from_address_hash` and `to_address_hash` aren't returned because they
  don't have an associated block number.

  When there are no addresses, the `reducer` is never called and the `initial` is returned in an `:ok` tuple.

  When an `t:Explorer.Chain.Address.t/0` `hash` is used multiple times, all unique `t:Explorer.Chain.Block.t/0` `number`
  will be returned.
  """
  @spec stream_unfetched_balances(
          initial :: accumulator,
          reducer ::
            (entry :: %{address_hash: Hash.Address.t(), block_number: Block.block_number()}, accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_balances(initial, reducer) when is_function(reducer, 2) do
    query =
      from(
        balance in CoinBalance,
        where: is_nil(balance.value_fetched_at),
        select: %{address_hash: balance.address_hash, block_number: balance.block_number}
      )

    Repo.stream_reduce(query, initial, reducer)
  end

  @doc """
  Returns a stream of all token balances that weren't fetched values.
  """
  @spec stream_unfetched_token_balances(
          initial :: accumulator,
          reducer :: (entry :: TokenBalance.t(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_token_balances(initial, reducer) when is_function(reducer, 2) do
    TokenBalance.unfetched_token_balances()
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Returns a stream of all blocks with unfetched internal transactions, using
  the `pending_block_operation` table.

  Only blocks with consensus are returned.

      iex> non_consensus = insert(:block, consensus: false)
      iex> insert(:pending_block_operation, block: non_consensus, fetch_internal_transactions: true)
      iex> unfetched = insert(:block)
      iex> insert(:pending_block_operation, block: unfetched, fetch_internal_transactions: true)
      iex> fetched = insert(:block)
      iex> insert(:pending_block_operation, block: fetched, fetch_internal_transactions: false)
      iex> {:ok, number_set} = Explorer.Chain.stream_blocks_with_unfetched_internal_transactions(
      ...>   MapSet.new(),
      ...>   fn number, acc ->
      ...>     MapSet.put(acc, number)
      ...>   end
      ...> )
      iex> non_consensus.number in number_set
      false
      iex> unfetched.number in number_set
      true
      iex> fetched.hash in number_set
      false

  """
  @spec stream_blocks_with_unfetched_internal_transactions(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_blocks_with_unfetched_internal_transactions(initial, reducer) when is_function(reducer, 2) do
    query =
      from(
        b in Block,
        join: pending_ops in assoc(b, :pending_operations),
        where: pending_ops.fetch_internal_transactions,
        where: b.consensus,
        where: b.update_count < 20,
        select: b.number
      )

    Repo.stream_reduce(query, initial, reducer)
  end

  @spec stream_blocks_with_unfetched_rewards(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_blocks_with_unfetched_rewards(initial, reducer) when is_function(reducer, 2) do
    query =
      from(
        b in Block,
        join: celo_pending_ops in Chain.CeloPendingEpochOperation,
        on: b.number == celo_pending_ops.block_number,
        where: celo_pending_ops.fetch_epoch_data,
        select: %{block_hash: b.hash, block_number: b.number, block_timestamp: b.timestamp},
        order_by: [asc: b.number]
      )

    Repo.stream_reduce(query, initial, reducer)
  end

  def stream_events_to_backfill(initial, reducer) do
    query =
      from(
        cet in ContractEventTracking,
        join: sc in SmartContract,
        on: sc.id == cet.smart_contract_id,
        where: cet.backfilled == false,
        where: cet.enabled == true,
        select: {sc.address_hash, cet.topic, cet.id}
      )

    Repo.stream_reduce(query, initial, reducer)
  end

  def remove_nonconsensus_blocks_from_pending_ops(block_hashes) do
    query =
      from(
        po in PendingBlockOperation,
        where: po.block_hash in ^block_hashes
      )

    {_, _} = Repo.delete_all(query)

    :ok
  end

  def remove_nonconsensus_blocks_from_pending_ops do
    query =
      from(
        po in PendingBlockOperation,
        inner_join: block in Block,
        on: block.hash == po.block_hash,
        where: block.consensus == false
      )

    {_, _} = Repo.delete_all(query)

    :ok
  end

  @spec stream_transactions_with_unfetched_created_contract_codes(
          fields :: [
            :block_hash
            | :created_contract_code_indexed_at
            | :from_address_hash
            | :gas
            | :gas_price
            | :gas_currency_hash
            | :gas_fee_recipient_hash
            | :gateway_fee
            | :hash
            | :index
            | :input
            | :nonce
            | :r
            | :s
            | :to_address_hash
            | :v
            | :value
          ],
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_transactions_with_unfetched_created_contract_codes(fields, initial, reducer)
      when is_function(reducer, 2) do
    query =
      from(t in Transaction,
        where:
          not is_nil(t.block_hash) and not is_nil(t.created_contract_address_hash) and
            is_nil(t.created_contract_code_indexed_at),
        select: ^fields
      )

    Repo.stream_reduce(query, initial, reducer)
  end

  @spec stream_mined_transactions(
          fields :: [
            :block_hash
            | :created_contract_code_indexed_at
            | :from_address_hash
            | :gas
            | :gas_price
            | :gas_currency_hash
            | :gas_fee_recipient_hash
            | :gateway_fee
            | :hash
            | :index
            | :input
            | :nonce
            | :r
            | :s
            | :to_address_hash
            | :v
            | :value
          ],
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_mined_transactions(fields, initial, reducer) when is_function(reducer, 2) do
    query =
      from(t in Transaction,
        where: not is_nil(t.block_hash) and not is_nil(t.nonce) and not is_nil(t.from_address_hash),
        select: ^fields
      )

    Repo.stream_reduce(query, initial, reducer)
  end

  @spec stream_pending_transactions(
          fields :: [
            :block_hash
            | :created_contract_code_indexed_at
            | :from_address_hash
            | :gas
            | :gas_price
            | :gas_currency_hash
            | :gas_fee_recipient_hash
            | :gateway_fee
            | :hash
            | :index
            | :input
            | :nonce
            | :r
            | :s
            | :to_address_hash
            | :v
            | :value
          ],
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_pending_transactions(fields, initial, reducer) when is_function(reducer, 2) do
    query =
      Transaction
      |> pending_transactions_query()
      |> select(^fields)

    Repo.stream_reduce(query, initial, reducer)
  end

  @doc """
  Returns a stream of all blocks that are marked as unfetched in `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`.
  For each uncle block a `hash` of nephew block and an `index` of the block in it are returned.

  When a block is fetched, its uncles are transformed into `t:Explorer.Chain.Block.SecondDegreeRelation.t/0` and can be
  returned.  Once the uncle is imported its corresponding `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`
  `uncle_fetched_at` will be set and it won't be returned anymore.
  """
  @spec stream_unfetched_uncles(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_uncles(initial, reducer) when is_function(reducer, 2) do
    query =
      from(bsdr in Block.SecondDegreeRelation,
        where: is_nil(bsdr.uncle_fetched_at) and not is_nil(bsdr.index),
        select: [:nephew_hash, :index]
      )

    Repo.stream_reduce(query, initial, reducer)
  end

  @doc """
  The number of `t:Explorer.Chain.Log.t/0`.

      iex> transaction = :transaction |> insert() |> with_block()
      iex> insert(:log, transaction: transaction, index: 0)
      iex> Explorer.Chain.log_count()
      1

  When there are no `t:Explorer.Chain.Log.t/0`.

      iex> Explorer.Chain.log_count()
      0

  """
  def log_count do
    Repo.one!(from(log in "logs", select: fragment("COUNT(*)")))
  end

  @doc """
  Max consensus block numbers.

  If blocks are skipped and inserted out of number order, the max number is still returned

      iex> insert(:block, number: 2)
      iex> insert(:block, number: 1)
      iex> Explorer.Chain.max_consensus_block_number()
      {:ok, 2}

  Non-consensus blocks are ignored

      iex> insert(:block, number: 3, consensus: false)
      iex> insert(:block, number: 2, consensus: true)
      iex> Explorer.Chain.max_consensus_block_number()
      {:ok, 2}

  If there are no blocks, `{:error, :not_found}` is returned

      iex> Explorer.Chain.max_consensus_block_number()
      {:error, :not_found}

  """
  @spec max_consensus_block_number() :: {:ok, Block.block_number()} | {:error, :not_found}
  def max_consensus_block_number do
    Block
    |> where(consensus: true)
    |> Repo.aggregate(:max, :number)
    |> case do
      nil -> {:error, :not_found}
      number -> {:ok, number}
    end
  end

  @spec max_non_consensus_block_number(integer | nil) :: {:ok, Block.block_number()} | {:error, :not_found}
  def max_non_consensus_block_number(max_consensus_block_number \\ nil) do
    max =
      if max_consensus_block_number do
        {:ok, max_consensus_block_number}
      else
        max_consensus_block_number()
      end

    case max do
      {:ok, number} ->
        query =
          from(block in Block,
            where: block.consensus == false,
            where: block.number > ^number
          )

        query
        |> Repo.aggregate(:max, :number)
        |> case do
          nil -> {:error, :not_found}
          number -> {:ok, number}
        end
    end
  end

  @spec block_height() :: block_height()
  def block_height do
    query = from(block in Block, select: coalesce(max(block.number), 0), where: block.consensus == true)

    Repo.one!(query)
  end

  def last_db_block_status do
    query =
      from(block in Block,
        select: {block.number, block.timestamp},
        where: block.consensus == true,
        order_by: [desc: block.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> block_status()
  end

  def last_cache_block_status do
    [
      paging_options: %PagingOptions{page_size: 1}
    ]
    |> list_blocks()
    |> List.last()
    |> case do
      %{timestamp: timestamp, number: number} ->
        block_status({number, timestamp})

      _ ->
        block_status(nil)
    end
  end

  @spec upsert_last_fetched_counter(map()) :: {:ok, LastFetchedCounter.t()} | {:error, Ecto.Changeset.t()}
  def upsert_last_fetched_counter(params) do
    changeset = LastFetchedCounter.changeset(%LastFetchedCounter{}, params)

    Repo.insert(changeset,
      on_conflict: :replace_all,
      conflict_target: [:counter_type]
    )
  end

  def get_last_fetched_counter(type) do
    query =
      from(
        last_fetched_counter in LastFetchedCounter,
        where: last_fetched_counter.counter_type == ^type,
        select: last_fetched_counter.value
      )

    Repo.one(query) || Decimal.new(0)
  end

  defp block_status({number, timestamp}) do
    now = DateTime.utc_now()
    last_block_period = DateTime.diff(now, timestamp, :millisecond)

    if last_block_period > Application.get_env(:explorer, :healthy_blocks_period) do
      {:error, number, timestamp}
    else
      {:ok, number, timestamp}
    end
  end

  defp block_status(nil), do: {:error, :no_blocks}

  def fetch_min_missing_block_cache do
    max_block_number = BlockNumber.get_max()

    min_missing_block_number =
      "min_missing_block_number"
      |> Chain.get_last_fetched_counter()
      |> Decimal.to_integer()

    if max_block_number > 0 do
      query =
        from(b in Block,
          right_join:
            missing_range in fragment(
              """
                (SELECT b1.number
                FROM generate_series((?)::integer, (?)::integer) AS b1(number)
                WHERE NOT EXISTS
                  (SELECT 1 FROM blocks b2 WHERE b2.number=b1.number AND b2.consensus))
              """,
              ^min_missing_block_number,
              ^max_block_number
            ),
          on: b.number == missing_range.number,
          select: min(missing_range.number)
        )

      query
      |> Repo.one(timeout: :infinity) || 0
    else
      0
    end
  end

  @doc """
  Calculates the ranges of missing consensus blocks in `range`.

  When there are no blocks, the entire range is missing.

      iex> Explorer.Chain.missing_block_number_ranges(0..5)
      [0..5]

  If the block numbers from `0` to `max_block_number/0` are contiguous, then no block numbers are missing

      iex> insert(:block, number: 0)
      iex> insert(:block, number: 1)
      iex> Explorer.Chain.missing_block_number_ranges(0..1)
      []

  If there are gaps between the `first` and `last` of `range`, then the missing numbers are compacted into ranges.
  Single missing numbers become ranges with the single number as the start and end.

      iex> insert(:block, number: 0)
      iex> insert(:block, number: 2)
      iex> insert(:block, number: 5)
      iex> Explorer.Chain.missing_block_number_ranges(0..5)
      [1..1, 3..4]

  Flipping the order of `first` and `last` in the `range` flips the order that the missing ranges are returned.  This
  allows `missing_block_numbers` to be used to generate the sequence down or up from a starting block number.

      iex> insert(:block, number: 0)
      iex> insert(:block, number: 2)
      iex> insert(:block, number: 5)
      iex> Explorer.Chain.missing_block_number_ranges(5..0)
      [4..3, 1..1]

  If only non-consensus blocks exist for a number, the number still counts as missing.

      iex> insert(:block, number: 0)
      iex> insert(:block, number: 1, consensus: false)
      iex> insert(:block, number: 2)
      iex> Explorer.Chain.missing_block_number_ranges(2..0)
      [1..1]

  if range starts with non-consensus block in the middle of the chain, it returns missing numbers.

      iex> insert(:block, number: 12859383, consensus: true)
      iex> insert(:block, number: 12859384, consensus: false)
      iex> insert(:block, number: 12859386, consensus: true)
      iex> Explorer.Chain.missing_block_number_ranges(12859384..12859385)
      [12859384..12859385]

      if range starts with missing block in the middle of the chain, it returns missing numbers.

      iex> insert(:block, number: 12859383, consensus: true)
      iex> insert(:block, number: 12859386, consensus: true)
      iex> Explorer.Chain.missing_block_number_ranges(12859384..12859385)
      [12859384..12859385]

  """
  @spec missing_block_number_ranges(Range.t()) :: [Range.t()]
  def missing_block_number_ranges(range)

  def missing_block_number_ranges(range_start..range_end) do
    range_min = min(range_start, range_end)
    range_max = max(range_start, range_end)

    ordered_missing_query =
      from(b in Block,
        right_join:
          missing_range in fragment(
            """
              (SELECT distinct b1.number
              FROM generate_series((?)::integer, (?)::integer) AS b1(number)
              WHERE NOT EXISTS
                (SELECT 1 FROM blocks b2 WHERE b2.number=b1.number AND b2.consensus))
            """,
            ^range_min,
            ^range_max
          ),
        on: b.number == missing_range.number,
        select: missing_range.number,
        order_by: missing_range.number,
        distinct: missing_range.number
      )

    missing_blocks = Repo.all(ordered_missing_query, timeout: :infinity)

    [block_ranges, last_block_range_start, last_block_range_end] =
      missing_blocks
      |> Enum.reduce([[], nil, nil], fn block_number, [block_ranges, last_block_range_start, last_block_range_end] ->
        cond do
          !last_block_range_start ->
            [block_ranges, block_number, block_number]

          block_number == last_block_range_end + 1 ->
            [block_ranges, last_block_range_start, block_number]

          true ->
            block_ranges = block_ranges_extend(block_ranges, last_block_range_start, last_block_range_end)
            [block_ranges, block_number, block_number]
        end
      end)

    final_block_ranges =
      if last_block_range_start && last_block_range_end do
        block_ranges_extend(block_ranges, last_block_range_start, last_block_range_end)
      else
        block_ranges
      end

    ordered_block_ranges =
      final_block_ranges
      |> Enum.sort(fn %Range{first: first1, last: _}, %Range{first: first2, last: _} ->
        if range_start <= range_end do
          first1 <= first2
        else
          first1 >= first2
        end
      end)
      |> Enum.map(fn %Range{first: first, last: last} = range ->
        if range_start <= range_end do
          range
        else
          if last > first do
            %Range{first: last, last: first, step: -1}
          else
            %Range{first: last, last: first, step: 1}
          end
        end
      end)

    ordered_block_ranges
  end

  defp block_ranges_extend(block_ranges, block_range_start, block_range_end) do
    # credo:disable-for-next-line
    block_ranges ++ [Range.new(block_range_start, block_range_end)]
  end

  @doc """
  Finds consensus `t:Explorer.Chain.Block.t/0` with `number`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Block.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Block.t/0` will not be included in the page `entries`.

  """
  @spec number_to_block(Block.block_number(), [necessity_by_association_option]) ::
          {:ok, Block.t()} | {:error, :not_found}
  def number_to_block(number, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Block
    |> where(consensus: true, number: ^number)
    |> join_associations(necessity_by_association)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  @spec number_to_any_block(Block.block_number(), [necessity_by_association_option]) ::
          {:ok, Block.t()} | {:error, :not_found}
  def number_to_any_block(number, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Block
    |> where(number: ^number)
    |> join_associations(necessity_by_association)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  @spec timestamp_to_block_number(DateTime.t(), :before | :after) :: {:ok, Block.block_number()} | {:error, :not_found}
  def timestamp_to_block_number(given_timestamp, closest) do
    {:ok, t} = Timex.format(given_timestamp, "%Y-%m-%d %H:%M:%S", :strftime)

    inner_query =
      from(
        block in Block,
        where: block.consensus == true,
        where:
          fragment("? <= TO_TIMESTAMP(?, 'YYYY-MM-DD HH24:MI:SS') + (1 * interval '1 minute')", block.timestamp, ^t),
        where:
          fragment("? >= TO_TIMESTAMP(?, 'YYYY-MM-DD HH24:MI:SS') - (1 * interval '1 minute')", block.timestamp, ^t)
      )

    query =
      from(
        block in subquery(inner_query),
        select: block,
        order_by:
          fragment("abs(extract(epoch from (? - TO_TIMESTAMP(?, 'YYYY-MM-DD HH24:MI:SS'))))", block.timestamp, ^t),
        limit: 1
      )

    query
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      %{:number => number, :timestamp => timestamp} ->
        block_number = get_block_number_based_on_closest(closest, timestamp, given_timestamp, number)

        {:ok, block_number}
    end
  end

  defp get_block_number_based_on_closest(closest, timestamp, given_timestamp, number) do
    case closest do
      :before ->
        if DateTime.compare(timestamp, given_timestamp) == :lt ||
             DateTime.compare(timestamp, given_timestamp) == :eq do
          number
        else
          number - 1
        end

      :after ->
        if DateTime.compare(timestamp, given_timestamp) == :lt ||
             DateTime.compare(timestamp, given_timestamp) == :eq do
          number + 1
        else
          number
        end
    end
  end

  @doc """
  Count of pending `t:Explorer.Chain.Transaction.t/0`.

  A count of all pending transactions.

      iex> insert(:transaction)
      iex> :transaction |> insert() |> with_block()
      iex> Explorer.Chain.pending_transaction_count()
      1

  """
  @spec pending_transaction_count() :: non_neg_integer()
  def pending_transaction_count do
    Transaction
    |> pending_transactions_query()
    |> Repo.aggregate(:count, :hash)
  end

  @doc """
  Returns the paged list of collated transactions that occurred recently from newest to oldest using `block_number`
  and `index`.

      iex> newest_first_transactions = 50 |> insert_list(:transaction) |> with_block() |> Enum.reverse()
      iex> oldest_seen = Enum.at(newest_first_transactions, 9)
      iex> paging_options = %Explorer.PagingOptions{page_size: 10, key: {oldest_seen.block_number, oldest_seen.index}}
      iex> recent_collated_transactions = Explorer.Chain.recent_collated_transactions(paging_options: paging_options)
      iex> length(recent_collated_transactions)
      10
      iex> hd(recent_collated_transactions).hash == Enum.at(newest_first_transactions, 10).hash
      true

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.Transaction.t/0` will not be included in the list.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, index}`) and. Results will be the transactions older than
      the `block_number` and `index` that are passed.

  """
  @spec recent_collated_transactions([paging_options | necessity_by_association_option]) :: [Transaction.t()]
  def recent_collated_transactions(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    if is_nil(paging_options.key) do
      paging_options.page_size
      |> Transactions.take_enough()
      |> case do
        nil ->
          transactions = fetch_recent_collated_transactions(paging_options, necessity_by_association)
          Transactions.update(transactions)
          transactions

        transactions ->
          transactions
      end
    else
      fetch_recent_collated_transactions(paging_options, necessity_by_association)
    end
  end

  def fetch_recent_collated_transactions(paging_options, necessity_by_association) do
    paging_options
    |> fetch_transactions()
    |> where([transaction], not is_nil(transaction.block_number) and not is_nil(transaction.index))
    |> join_associations(necessity_by_association)
    |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
    |> Repo.all()
  end

  @doc """
  Return the list of pending transactions that occurred recently.

      iex> 2 |> insert_list(:transaction)
      iex> :transaction |> insert() |> with_block()
      iex> 8 |> insert_list(:transaction)
      iex> recent_pending_transactions = Explorer.Chain.recent_pending_transactions()
      iex> length(recent_pending_transactions)
      10
      iex> Enum.all?(recent_pending_transactions, fn %Explorer.Chain.Transaction{block_hash: block_hash} ->
      ...>   is_nil(block_hash)
      ...> end)
      true

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.Transaction.t/0` will not be included in the list.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` (defaults to
      `#{@default_paging_options.page_size}`) and `:key` (a tuple of the lowest/oldest `{inserted_at, hash}`) and.
      Results will be the transactions older than the `inserted_at` and `hash` that are passed.

  """
  @spec recent_pending_transactions([paging_options | necessity_by_association_option]) :: [Transaction.t()]
  def recent_pending_transactions(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    Transaction
    |> page_pending_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> pending_transactions_query()
    |> order_by([transaction], desc: transaction.inserted_at, desc: transaction.hash)
    |> join_associations(necessity_by_association)
    |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
    |> Repo.all()
  end

  def pending_transactions_query(query) do
    from(transaction in query,
      where: is_nil(transaction.block_hash) and (is_nil(transaction.error) or transaction.error != "dropped/replaced")
    )
  end

  def pending_transactions_list do
    query =
      Transaction
      |> pending_transactions_query()
      |> Repo.all(timeout: :infinity)
  end

  def pending_transactions_count do
    query =
      Transaction
      |> pending_transactions_query()
      |> Repo.aggregate(:count, :hash)
  end

  @doc """
  Returns the list of empty blocks from the DB which have not marked with `t:Explorer.Chain.Block.is_empty/0`.
  This query used for initializtion of Indexer.EmptyBlocksSanitizer
  """
  def unprocessed_empty_blocks_query_list(limit) do
    query =
      from(block in Block,
        left_join: transaction in Transaction,
        on: block.number == transaction.block_number,
        where: is_nil(transaction.block_number),
        where: is_nil(block.is_empty),
        where: block.consensus == true,
        select: {block.number, block.hash},
        order_by: [desc: block.number],
        limit: ^limit
      )

    query
    |> Repo.all(timeout: :infinity)
  end

  @doc """
  The `string` must start with `0x`, then is converted to an integer and then to `t:Explorer.Chain.Hash.Address.t/0`.

      iex> Explorer.Chain.string_to_address_hash("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed")
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed :: big-integer-size(20)-unit(8)>>
        }
      }

  `String.t` format must always have 40 hexadecimal digits after the `0x` base prefix.

      iex> Explorer.Chain.string_to_address_hash("0x0")
      :error

  """
  @spec string_to_address_hash(String.t()) :: {:ok, Hash.Address.t()} | :error
  def string_to_address_hash(string) when is_binary(string) do
    Hash.Address.cast(string)
  end

  @doc """
  The `string` must start with `0x`, then is converted to an integer and then to `t:Explorer.Chain.Hash.t/0`.

      iex> Explorer.Chain.string_to_block_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 32,
          bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
        }
      }

  `String.t` format must always have 64 hexadecimal digits after the `0x` base prefix.

      iex> Explorer.Chain.string_to_block_hash("0x0")
      :error

  """
  @spec string_to_block_hash(String.t()) :: {:ok, Hash.t()} | :error
  def string_to_block_hash(string) when is_binary(string) do
    Hash.Full.cast(string)
  end

  @doc """
  The `string` must start with `0x`, then is converted to an integer and then to `t:Explorer.Chain.Hash.t/0`.

      iex> Explorer.Chain.string_to_transaction_hash(
      ...>  "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 32,
          bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
        }
      }

  `String.t` format must always have 64 hexadecimal digits after the `0x` base prefix.

      iex> Explorer.Chain.string_to_transaction_hash("0x0")
      :error

  """
  @spec string_to_transaction_hash(String.t()) :: {:ok, Hash.t()} | :error
  def string_to_transaction_hash(string) when is_binary(string) do
    Hash.Full.cast(string)
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Transaction.t/0`.

  Estimated count of both collated and pending transactions using the transactions table statistics.

  Celo changes: Implemented via db trigger mechanism on `transactions` table directly and returns accurate tx count
    with fallback to gc estimate.
  """
  @spec transaction_estimated_count() :: non_neg_integer()
  def transaction_estimated_count do
    count = CeloTxStats.transaction_count()

    case count do
      nil ->
        Logger.warn("Couldn't retrieve tx count from celo_transaction_stats - falling back to PG gc estimation")

        %Postgrex.Result{rows: [[rows]]} =
          SQL.query!(Repo, "SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname='transactions'")

        rows

      n ->
        n
    end
  end

  @spec total_gas_usage() :: non_neg_integer()
  def total_gas_usage do
    total_gas = CeloTxStats.total_gas()

    if is_nil(total_gas) do
      0
    else
      total_gas
    end
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Block.t/0`.

  Estimated count of consensus blocks.
  """
  @spec block_estimated_count() :: non_neg_integer()
  def block_estimated_count do
    cached_value = BlockCount.get_count()

    if is_nil(cached_value) do
      %Postgrex.Result{rows: [[count]]} = Repo.query!("SELECT reltuples FROM pg_class WHERE relname = 'blocks';")

      trunc(count * 0.90)
    else
      cached_value
    end
  end

  @doc """
  `t:Explorer.Chain.InternalTransaction/0`s in `t:Explorer.Chain.Transaction.t/0` with `hash`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{index}`). Results will be the internal transactions older than
      the `index` that is passed.

  """

  @spec all_transaction_to_internal_transactions(Hash.Full.t(), [paging_options | necessity_by_association_option]) :: [
          InternalTransaction.t()
        ]
  def all_transaction_to_internal_transactions(hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    InternalTransaction
    |> for_parent_transaction(hash)
    |> join_associations(necessity_by_association)
    |> InternalTransaction.where_nonpending_block()
    |> page_internal_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([internal_transaction], asc: internal_transaction.index)
    |> preload(:transaction)
    |> Repo.all()
  end

  @spec transaction_to_internal_transactions(Hash.Full.t(), [paging_options | necessity_by_association_option]) :: [
          InternalTransaction.t()
        ]
  def transaction_to_internal_transactions(hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    InternalTransaction
    |> for_parent_transaction(hash)
    |> join_associations(necessity_by_association)
    |> where_transaction_has_multiple_internal_transactions()
    |> InternalTransaction.where_is_different_from_parent_transaction()
    |> InternalTransaction.where_nonpending_block()
    |> page_internal_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([internal_transaction], asc: internal_transaction.index)
    |> preload(:transaction)
    |> Repo.all()
  end

  @doc """
  Finds all `t:Explorer.Chain.Log.t/0`s for `t:Explorer.Chain.Transaction.t/0`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Log.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Log.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{index}`). Results will be the transactions older than
      the `index` that are passed.

  """
  @spec transaction_to_logs(Hash.Full.t(), [paging_options | necessity_by_association_option]) :: [Log.t()]
  def transaction_to_logs(transaction_hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    log_with_transactions =
      from(log in Log,
        inner_join: transaction in Transaction,
        on:
          transaction.block_hash == log.block_hash and transaction.block_number == log.block_number and
            transaction.hash == log.transaction_hash
      )

    log_with_transactions
    |> where([_, transaction], transaction.hash == ^transaction_hash)
    |> page_logs(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([log], asc: log.index)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  @doc """
  Finds all `t:Explorer.Chain.TokenTransfer.t/0`s for `t:Explorer.Chain.Transaction.t/0`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.TokenTransfer.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.TokenTransfer.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (in the form of `%{"inserted_at" => inserted_at}`). Results will be the transactions older than
      the `index` that are passed.

  """
  @spec transaction_to_token_transfers(Hash.Full.t(), [paging_options | necessity_by_association_option]) :: [
          TokenTransfer.t()
        ]
  def transaction_to_token_transfers(transaction_hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    TokenTransfer
    |> join(:inner, [token_transfer], transaction in assoc(token_transfer, :transaction))
    |> where(
      [token_transfer, transaction],
      transaction.hash == ^transaction_hash and token_transfer.block_hash == transaction.block_hash and
        token_transfer.block_number == transaction.block_number
    )
    |> TokenTransfer.page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([token_transfer], asc: token_transfer.inserted_at)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  @doc """
  Converts `transaction` to the status of the `t:Explorer.Chain.Transaction.t/0` whether pending or collated.

  ## Returns

    * `:pending` - the transaction has not be confirmed in a block yet.
    * `:awaiting_internal_transactions` - the transaction happened in a pre-Byzantium block or on a chain like Ethereum
      Classic (ETC) that never adopted [EIP-658](https://github.com/Arachnid/EIPs/blob/master/EIPS/eip-658.md), which
      add transaction status to transaction receipts, so the status can only be derived whether the first internal
      transaction has an error.
    * `:success` - the transaction has been confirmed in a block
    * `{:error, :awaiting_internal_transactions}` - the transactions happened post-Byzantium, but the error message
       requires the internal transactions.
    * `{:error, reason}` - the transaction failed due to `reason` in its first internal transaction.

  """
  @spec transaction_to_status(Transaction.t()) ::
          :pending
          | :awaiting_internal_transactions
          | :success
          | {:error, :awaiting_internal_transactions}
          | {:error, reason :: String.t()}
  def transaction_to_status(%Transaction{error: "dropped/replaced"}), do: {:error, "dropped/replaced"}
  def transaction_to_status(%Transaction{block_hash: nil, status: nil}), do: :pending
  def transaction_to_status(%Transaction{status: nil}), do: :awaiting_internal_transactions
  def transaction_to_status(%Transaction{status: :ok}), do: :success

  def transaction_to_status(%Transaction{status: :error, error: nil}),
    do: {:error, :awaiting_internal_transactions}

  def transaction_to_status(%Transaction{status: :error, error: error}) when is_binary(error), do: {:error, error}

  def transaction_to_revert_reason(transaction) do
    %Transaction{revert_reason: revert_reason} = transaction

    if revert_reason == nil do
      fetch_tx_revert_reason(transaction)
    else
      revert_reason
    end
  end

  def fetch_tx_revert_reason(
        %Transaction{
          block_number: block_number,
          to_address_hash: to_address_hash,
          from_address_hash: from_address_hash,
          input: data,
          gas: gas,
          gas_price: gas_price,
          value: value
        } = transaction
      ) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    gas_hex =
      if gas do
        gas_hex_without_prefix =
          gas
          |> Decimal.to_integer()
          |> Integer.to_string(16)
          |> String.downcase()

        "0x" <> gas_hex_without_prefix
      else
        "0x0"
      end

    req =
      EthereumJSONRPCTransaction.eth_call_request(
        0,
        block_number,
        data,
        to_address_hash,
        from_address_hash,
        gas_hex,
        Wei.hex_format(gas_price),
        Wei.hex_format(value)
      )

    revert_reason =
      case EthereumJSONRPC.json_rpc(req, json_rpc_named_arguments) do
        {:error, %{message: message}} ->
          message

        _ ->
          ""
      end

    formatted_revert_reason =
      revert_reason
      |> format_revert_reason_message()

    if byte_size(formatted_revert_reason) > 0 do
      transaction
      |> Changeset.change(%{revert_reason: formatted_revert_reason})
      |> Repo.update()
    end

    formatted_revert_reason
  end

  def format_revert_reason_message(revert_reason) do
    message =
      case revert_reason do
        @revert_msg_prefix_1 <> rest ->
          rest

        @revert_msg_prefix_2 <> rest ->
          rest

        @revert_msg_prefix_3 <> rest ->
          extract_revert_reason_message_wrapper(rest)

        @revert_msg_prefix_4 <> rest ->
          extract_revert_reason_message_wrapper(rest)

        @revert_msg_prefix_5 <> rest ->
          extract_revert_reason_message_wrapper(rest)

        revert_reason_full ->
          revert_reason_full
      end

    if String.valid?(message), do: message, else: revert_reason
  end

  defp extract_revert_reason_message_wrapper(revert_reason_message) do
    case revert_reason_message do
      "0x" <> hex ->
        extract_revert_reason_message(hex)

      _ ->
        revert_reason_message
    end
  end

  defp extract_revert_reason_message(hex) do
    case hex do
      @revert_error_method_id <> msg_with_offset ->
        [msg] =
          msg_with_offset
          |> Base.decode16!(case: :mixed)
          |> TypeDecoder.decode_raw([:string])

        msg

      _ ->
        hex
    end
  end

  @doc """
  The `t:Explorer.Chain.Transaction.t/0` or `t:Explorer.Chain.InternalTransaction.t/0` `value` of the `transaction` in
  `unit`.
  """
  @spec value(InternalTransaction.t(), :wei) :: Wei.wei()
  @spec value(InternalTransaction.t(), :gwei) :: Wei.gwei()
  @spec value(InternalTransaction.t(), :ether) :: Wei.ether()
  @spec value(Transaction.t(), :wei) :: Wei.wei()
  @spec value(Transaction.t(), :gwei) :: Wei.gwei()
  @spec value(Transaction.t(), :ether) :: Wei.ether()
  def value(%type{value: value}, unit) when type in [InternalTransaction, Transaction] do
    Wei.to(value, unit)
  end

  def smart_contract_bytecode(address_hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^address_hash,
        select: address.contract_code
      )

    query
    |> Repo.one()
    |> Data.to_string()
  end

  def smart_contract_creation_tx_bytecode(address_hash) do
    creation_tx_query =
      from(
        tx in Transaction,
        left_join: a in Address,
        on: tx.created_contract_address_hash == a.hash,
        where: tx.created_contract_address_hash == ^address_hash,
        where: tx.status == ^1,
        select: %{init: tx.input, created_contract_code: a.contract_code}
      )

    tx_input =
      creation_tx_query
      |> Repo.one()

    if tx_input do
      with %{init: input, created_contract_code: created_contract_code} <- tx_input do
        %{init: Data.to_string(input), created_contract_code: Data.to_string(created_contract_code)}
      end
    else
      creation_int_tx_query =
        from(
          itx in InternalTransaction,
          join: t in assoc(itx, :transaction),
          where: itx.created_contract_address_hash == ^address_hash,
          where: t.status == ^1,
          select: %{init: itx.init, created_contract_code: itx.created_contract_code}
        )

      res = creation_int_tx_query |> Repo.one()

      case res do
        %{init: init, created_contract_code: created_contract_code} ->
          init_str = Data.to_string(init)
          created_contract_code_str = Data.to_string(created_contract_code)
          %{init: init_str, created_contract_code: created_contract_code_str}

        _ ->
          nil
      end
    end
  end

  @doc """
  Checks if an address is a contract
  """
  @spec contract_address?(String.t(), non_neg_integer(), Keyword.t()) :: boolean() | :json_rpc_error
  def contract_address?(address_hash, block_number, json_rpc_named_arguments \\ []) do
    {:ok, binary_hash} = Explorer.Chain.Hash.Address.cast(address_hash)

    query =
      from(
        address in Address,
        where: address.hash == ^binary_hash
      )

    address = Repo.one(query)

    cond do
      is_nil(address) ->
        block_quantity = integer_to_quantity(block_number)

        case EthereumJSONRPC.fetch_codes(
               [%{block_quantity: block_quantity, address: address_hash}],
               json_rpc_named_arguments
             ) do
          {:ok, %EthereumJSONRPC.FetchedCodes{params_list: fetched_codes}} ->
            result = List.first(fetched_codes)

            result && !(is_nil(result[:code]) || result[:code] == "" || result[:code] == "0x")

          _ ->
            :json_rpc_error
        end

      is_nil(address.contract_code) ->
        false

      true ->
        true
    end
  end

  @doc """
  Fetches contract creation input data.
  """
  @spec contract_creation_input_data(String.t()) :: nil | String.t()
  def contract_creation_input_data(address_hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^address_hash,
        preload: [:contracts_creation_internal_transaction, :contracts_creation_transaction]
      )

    contract_address = Repo.one(query)

    contract_creation_input_data_from_address(contract_address)
  end

  # credo:disable-for-next-line /Complexity/
  defp contract_creation_input_data_from_address(address) do
    internal_transaction = address && address.contracts_creation_internal_transaction
    transaction = address && address.contracts_creation_transaction

    cond do
      is_nil(address) ->
        ""

      internal_transaction && internal_transaction.input ->
        Data.to_string(internal_transaction.input)

      internal_transaction && internal_transaction.init ->
        Data.to_string(internal_transaction.init)

      transaction && transaction.input ->
        Data.to_string(transaction.input)

      is_nil(transaction) && is_nil(internal_transaction) &&
          not is_nil(address.contract_code) ->
        %Explorer.Chain.Data{bytes: bytes} = address.contract_code
        Base.encode16(bytes, case: :lower)

      true ->
        ""
    end
  end

  @doc """
  Inserts a `t:SmartContract.t/0`.

  As part of inserting a new smart contract, an additional record is inserted for
  naming the address for reference.
  """
  @spec create_smart_contract(map()) :: {:ok, SmartContract.t()} | {:error, Ecto.Changeset.t()}
  def create_smart_contract(attrs \\ %{}, external_libraries \\ [], secondary_sources \\ []) do
    new_contract = %SmartContract{}

    smart_contract_changeset =
      new_contract
      |> SmartContract.changeset(attrs)
      |> Changeset.put_change(:external_libraries, external_libraries)
      |> apply_smart_contract_contract_code_md5_changeset

    new_contract_additional_source = %SmartContractAdditionalSource{}

    smart_contract_additional_sources_changesets =
      if secondary_sources do
        secondary_sources
        |> Enum.map(fn changeset ->
          new_contract_additional_source
          |> SmartContractAdditionalSource.changeset(changeset)
        end)
      else
        []
      end

    address_hash = Changeset.get_field(smart_contract_changeset, :address_hash)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    insert_contract_query =
      Multi.new()
      |> Multi.run(:set_address_verified, fn repo, _ -> set_address_verified(repo, address_hash) end)
      |> Multi.run(:clear_primary_address_names, fn repo, _ -> clear_primary_address_names(repo, address_hash) end)
      |> Multi.run(:insert_address_name, fn repo, _ ->
        name = Changeset.get_field(smart_contract_changeset, :name)
        create_address_name(repo, name, address_hash)
      end)
      |> Multi.insert(:smart_contract, smart_contract_changeset)

    insert_contract_query_with_additional_sources =
      smart_contract_additional_sources_changesets
      |> Enum.with_index()
      |> Enum.reduce(insert_contract_query, fn {changeset, index}, multi ->
        Multi.insert(multi, "smart_contract_additional_source_#{Integer.to_string(index)}", changeset)
      end)

    insert_result =
      insert_contract_query_with_additional_sources
      |> Repo.transaction()

    case insert_result do
      {:ok, %{smart_contract: smart_contract}} ->
        {:ok, smart_contract}

      {:error, :smart_contract, changeset, _} ->
        {:error, changeset}

      {:error, :proxy_address_contract, changeset, _} ->
        {:error, changeset}

      {:error, :set_address_verified, message, _} ->
        {:error, message}
    end
  end

  defp apply_smart_contract_contract_code_md5_changeset(changeset) do
    address_hash = Changeset.get_field(changeset, :address_hash)

    case Repo.get(Address, address_hash) do
      %Address{} = address ->
        Changeset.put_change(changeset, :contract_byte_code_md5, address |> Address.contract_code_md5())

      _ ->
        changeset
    end
  end

  @doc """
  Updates a `t:SmartContract.t/0`.

  Has the similar logic as create_smart_contract/1.
  Used in cases when you need to update row in DB contains SmartContract, e.g. in case of changing
  status `partially verified` to `fully verified` (re-verify).
  """
  @spec update_smart_contract(map()) :: {:ok, SmartContract.t()} | {:error, Ecto.Changeset.t()}
  def update_smart_contract(attrs \\ %{}, external_libraries \\ [], secondary_sources \\ []) do
    address_hash = Map.get(attrs, :address_hash)

    query =
      from(
        smart_contract in SmartContract,
        where: smart_contract.address_hash == ^address_hash
      )

    query_sources =
      from(
        source in SmartContractAdditionalSource,
        where: source.address_hash == ^address_hash
      )

    _delete_sources = Repo.delete_all(query_sources)

    smart_contract = Repo.one(query)

    smart_contract_changeset =
      smart_contract
      |> SmartContract.changeset(attrs)
      |> Changeset.put_change(:external_libraries, external_libraries)
      |> apply_smart_contract_contract_code_md5_changeset

    new_contract_additional_source = %SmartContractAdditionalSource{}

    smart_contract_additional_sources_changesets =
      if secondary_sources do
        secondary_sources
        |> Enum.map(fn changeset ->
          new_contract_additional_source
          |> SmartContractAdditionalSource.changeset(changeset)
        end)
      else
        []
      end

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    insert_contract_query =
      Multi.new()
      |> Multi.update(:smart_contract, smart_contract_changeset)

    insert_contract_query_with_additional_sources =
      smart_contract_additional_sources_changesets
      |> Enum.with_index()
      |> Enum.reduce(insert_contract_query, fn {changeset, index}, multi ->
        Multi.insert(multi, "smart_contract_additional_source_#{Integer.to_string(index)}", changeset)
      end)

    insert_result =
      insert_contract_query_with_additional_sources
      |> Repo.transaction()

    case insert_result do
      {:ok, %{smart_contract: smart_contract}} ->
        {:ok, smart_contract}

      {:error, :smart_contract, changeset, _} ->
        {:error, changeset}

      {:error, :set_address_verified, message, _} ->
        {:error, message}
    end
  end

  defp set_address_verified(repo, address_hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^address_hash
      )

    case repo.update_all(query, set: [verified: true]) do
      {1, _} -> {:ok, []}
      _ -> {:error, "There was an error annotating that the address has been verified."}
    end
  end

  defp set_address_decompiled(repo, address_hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^address_hash
      )

    case repo.update_all(query, set: [decompiled: true]) do
      {1, _} -> {:ok, []}
      _ -> {:error, "There was an error annotating that the address has been decompiled."}
    end
  end

  # defp set_address_proxy(repo, proxy_address, implementation_address) do
  #   params = %{
  #     proxy_address: proxy_address,
  #     implementation_address: implementation_address
  #   }

  #   Logger.debug(fn -> "Setting Proxy Address Mapping: #{proxy_address} - #{implementation_address}" end)

  #   %ProxyContract{}
  #   |> ProxyContract.changeset(params)
  #   |> repo.insert(
  #     on_conflict: :replace_all,
  #     conflict_target: [:proxy_address]
  #   )
  # end

  defp clear_primary_address_names(repo, address_hash) do
    query =
      from(
        address_name in Address.Name,
        where: address_name.address_hash == ^address_hash,
        # Enforce Name ShareLocks order (see docs: sharelocks.md)
        order_by: [asc: :address_hash, asc: :name],
        lock: "FOR UPDATE"
      )

    repo.update_all(
      from(n in Address.Name, join: s in subquery(query), on: n.address_hash == s.address_hash and n.name == s.name),
      set: [primary: false]
    )

    {:ok, []}
  end

  defp create_address_name(repo, name, address_hash) do
    params = %{
      address_hash: address_hash,
      name: name,
      primary: true
    }

    %Address.Name{}
    |> Address.Name.changeset(params)
    |> repo.insert(on_conflict: :nothing, conflict_target: [:address_hash, :name])
  end

  @spec address_hash_to_address_with_source_code(Hash.Address.t()) :: Address.t() | nil
  def address_hash_to_address_with_source_code(address_hash) do
    case Repo.get(Address, address_hash) do
      nil ->
        nil

      address ->
        address_with_smart_contract =
          Repo.preload(address, [:smart_contract, :decompiled_smart_contracts, :smart_contract_additional_sources])

        if address_with_smart_contract.smart_contract do
          formatted_code = format_source_code_output(address_with_smart_contract.smart_contract)

          %{
            address_with_smart_contract
            | smart_contract: %{address_with_smart_contract.smart_contract | contract_source_code: formatted_code}
          }
        else
          address_verified_twin_contract =
            Chain.get_minimal_proxy_template(address_hash) ||
              Chain.get_address_verified_twin_contract(address_hash).verified_contract

          if address_verified_twin_contract do
            formatted_code = format_source_code_output(address_verified_twin_contract)

            %{
              address_with_smart_contract
              | smart_contract: %{address_verified_twin_contract | contract_source_code: formatted_code}
            }
          else
            address_with_smart_contract
          end
        end
    end
  end

  def get_proxied_address(address_hash) do
    query =
      from(contract in ProxyContract,
        where: contract.proxy_address == ^address_hash
      )

    query
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      proxy_contract -> {:ok, proxy_contract.implementation_address}
    end
  end

  defp format_source_code_output(smart_contract), do: smart_contract.contract_source_code

  @doc """
  Finds metadata for verification of a contract from verified twins: contracts with the same bytecode
  which were verified previously, returns a single t:SmartContract.t/0
  """
  def get_address_verified_twin_contract(address_hash) do
    case Repo.get(Address, address_hash) do
      nil ->
        %{:verified_contract => nil, :additional_sources => nil}

      target_address ->
        target_address_hash = target_address.hash
        contract_code = target_address.contract_code

        case contract_code do
          %Data{bytes: contract_code_bytes} ->
            contract_code_md5 = Address.contract_code_md5(contract_code_bytes)

            verified_contract_twin_query =
              from(
                sc in SmartContract,
                where: sc.contract_byte_code_md5 == ^contract_code_md5,
                where: sc.address_hash != ^target_address_hash,
                limit: 1
              )

            verified_contract_twin =
              verified_contract_twin_query
              |> Repo.one()

            verified_contract_twin_additional_sources = get_contract_additional_sources(verified_contract_twin)

            %{
              :verified_contract => verified_contract_twin,
              :additional_sources => verified_contract_twin_additional_sources
            }

          _ ->
            %{:verified_contract => nil, :additional_sources => nil}
        end
    end
  end

  def get_minimal_proxy_template(address_hash) do
    minimal_proxy_template =
      case Repo.get(Address, address_hash) do
        nil ->
          nil

        target_address ->
          contract_code = target_address.contract_code

          case contract_code do
            %Chain.Data{bytes: contract_code_bytes} ->
              contract_bytecode = Base.encode16(contract_code_bytes, case: :lower)

              get_minimal_proxy_from_template_code(contract_bytecode)

            _ ->
              nil
          end
      end

    minimal_proxy_template
  end

  defp get_minimal_proxy_from_template_code(contract_bytecode) do
    case contract_bytecode do
      "363d3d373d3d3d363d73" <> <<template_address::binary-size(40)>> <> _ ->
        template_address = "0x" <> template_address

        query =
          from(
            smart_contract in SmartContract,
            where: smart_contract.address_hash == ^template_address,
            select: smart_contract
          )

        template =
          query
          |> Repo.one(timeout: 10_000)

        template

      _ ->
        nil
    end
  end

  defp get_contract_additional_sources(verified_contract_twin) do
    if verified_contract_twin do
      verified_contract_twin_additional_sources_query =
        from(
          s in SmartContractAdditionalSource,
          where: s.address_hash == ^verified_contract_twin.address_hash
        )

      verified_contract_twin_additional_sources_query
      |> Repo.all()
    else
      []
    end
  end

  @spec address_hash_to_smart_contract(Hash.Address.t()) :: SmartContract.t() | nil
  def address_hash_to_smart_contract(address_hash) do
    query =
      from(
        smart_contract in SmartContract,
        where: smart_contract.address_hash == ^address_hash
      )

    current_smart_contract = Repo.one(query)

    if current_smart_contract do
      current_smart_contract
    else
      address_verified_twin_contract =
        Chain.get_minimal_proxy_template(address_hash) ||
          Chain.get_address_verified_twin_contract(address_hash).verified_contract

      if address_verified_twin_contract do
        Map.put(address_verified_twin_contract, :address_hash, address_hash)
      else
        current_smart_contract
      end
    end
  end

  def smart_contract_fully_verified?(address_hash_str) when is_binary(address_hash_str) do
    case string_to_address_hash(address_hash_str) do
      {:ok, address_hash} ->
        check_fully_verified(address_hash)

      _ ->
        false
    end
  end

  def smart_contract_fully_verified?(address_hash) do
    check_fully_verified(address_hash)
  end

  defp check_fully_verified(address_hash) do
    query =
      from(
        smart_contract in SmartContract,
        where: smart_contract.address_hash == ^address_hash
      )

    result = Repo.one(query)

    if result, do: !result.partially_verified
  end

  def smart_contract_verified?(address_hash_str) when is_binary(address_hash_str) do
    case string_to_address_hash(address_hash_str) do
      {:ok, address_hash} ->
        check_verified(address_hash)

      _ ->
        false
    end
  end

  def smart_contract_verified?(address_hash) do
    check_verified(address_hash)
  end

  defp check_verified(address_hash) do
    query =
      from(
        smart_contract in SmartContract,
        where: smart_contract.address_hash == ^address_hash
      )

    if Repo.one(query), do: true, else: false
  end

  defp fetch_transactions(paging_options \\ nil, from_block \\ nil, to_block \\ nil) do
    Transaction
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
    |> where_block_number_in_period(from_block, to_block)
    |> handle_paging_options(paging_options)
  end

  defp fetch_transactions_in_ascending_order_by_index(paging_options) do
    Transaction
    |> order_by([transaction], desc: transaction.block_number, asc: transaction.index)
    |> handle_paging_options(paging_options)
  end

  defp for_parent_transaction(query, %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash) do
    from(
      child in query,
      inner_join: transaction in assoc(child, :transaction),
      where: transaction.hash == ^hash
    )
  end

  defp handle_paging_options(query, nil), do: query

  defp handle_paging_options(query, paging_options) do
    query
    |> page_transaction(paging_options)
    |> limit(^paging_options.page_size)
  end

  defp join_association(query, [{association, nested_preload}], necessity)
       when is_atom(association) and is_atom(nested_preload) do
    case necessity do
      :optional ->
        preload(query, [{^association, ^nested_preload}])

      :required ->
        from(q in query,
          inner_join: a in assoc(q, ^association),
          left_join: b in assoc(a, ^nested_preload),
          preload: [{^association, {a, [{^nested_preload, b}]}}]
        )
    end
  end

  defp join_association(query, association, necessity) when is_atom(association) do
    case necessity do
      :optional ->
        preload(query, ^association)

      :required ->
        from(q in query, inner_join: a in assoc(q, ^association), preload: [{^association, a}])
    end
  end

  defp join_association(query, [{arg1, arg2, arg3}], :optional) do
    preload(query, [{^arg1, [{^arg2, ^arg3}]}])
  end

  defp join_association(query, [{arg1, arg2, arg3, arg4}], :optional) do
    preload(query, [{^arg1, [{^arg2, [{^arg3, ^arg4}]}]}])
  end

  defp join_association(query, [{arg1, arg2, arg3, arg4, arg5}], :optional) do
    preload(query, [{^arg1, [{^arg2, [{^arg3, [{^arg4, ^arg5}]}]}]}])
  end

  defp join_associations(query, necessity_by_association) when is_map(necessity_by_association) do
    Enum.reduce(necessity_by_association, query, fn {association, join}, acc_query ->
      join_association(acc_query, association, join)
    end)
  end

  defp page_addresses(query, %PagingOptions{key: nil}), do: query

  defp page_addresses(query, %PagingOptions{key: {coin_balance, hash}}) do
    from(address in query,
      where:
        (address.fetched_coin_balance == ^coin_balance and address.hash > ^hash) or
          address.fetched_coin_balance < ^coin_balance
    )
  end

  defp page_tokens(query, %PagingOptions{key: nil}), do: query

  defp page_tokens(query, %PagingOptions{key: {holder_count, token_name}}) do
    from(token in query,
      where:
        (token.holder_count == ^holder_count and token.name > ^token_name) or
          token.holder_count < ^holder_count
    )
  end

  defp page_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_blocks(query, %PagingOptions{key: {block_number}}) do
    where(query, [block], block.number < ^block_number)
  end

  defp page_coin_balances(query, %PagingOptions{key: nil}), do: query

  defp page_coin_balances(query, %PagingOptions{key: {block_number}}) do
    where(query, [coin_balance], coin_balance.block_number < ^block_number)
  end

  defp page_internal_transaction(_, _, _ \\ %{index_int_tx_desc_order: false})

  defp page_internal_transaction(query, %PagingOptions{key: nil}, _), do: query

  defp page_internal_transaction(query, %PagingOptions{key: {block_number, transaction_index, index}}, %{
         index_int_tx_desc_order: desc
       }) do
    hardcoded_where_for_page_int_tx(query, block_number, transaction_index, index, desc)
  end

  defp page_internal_transaction(query, %PagingOptions{key: {index}}, %{index_int_tx_desc_order: desc}) do
    if desc do
      where(query, [internal_transaction], internal_transaction.index < ^index)
    else
      where(query, [internal_transaction], internal_transaction.index > ^index)
    end
  end

  defp hardcoded_where_for_page_int_tx(query, block_number, transaction_index, index, false),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number < ^block_number or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index < ^transaction_index) or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index == ^transaction_index and internal_transaction.index > ^index)
      )

  defp hardcoded_where_for_page_int_tx(query, block_number, transaction_index, index, true),
    do:
      where(
        query,
        [internal_transaction],
        internal_transaction.block_number < ^block_number or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index < ^transaction_index) or
          (internal_transaction.block_number == ^block_number and
             internal_transaction.transaction_index == ^transaction_index and internal_transaction.index < ^index)
      )

  defp page_logs(query, %PagingOptions{key: nil}), do: query

  defp page_logs(query, %PagingOptions{key: {_, index}}) do
    where(query, [log], log.index > ^index)
  end

  defp page_pending_transaction(query, %PagingOptions{key: nil}), do: query

  defp page_pending_transaction(query, %PagingOptions{key: {inserted_at, hash}}) do
    where(
      query,
      [transaction],
      transaction.inserted_at < ^inserted_at or (transaction.inserted_at == ^inserted_at and transaction.hash < ^hash)
    )
  end

  defp page_transaction(query, %PagingOptions{key: nil}), do: query

  defp page_transaction(query, %PagingOptions{is_pending_tx: true} = options),
    do: page_pending_transaction(query, options)

  defp page_transaction(query, %PagingOptions{key: {block_number, index}, is_index_in_asc_order: true}) do
    where(
      query,
      [transaction],
      transaction.block_number < ^block_number or
        (transaction.block_number == ^block_number and transaction.index > ^index)
    )
  end

  defp page_transaction(query, %PagingOptions{key: {block_number, index}}) do
    where(
      query,
      [transaction],
      transaction.block_number < ^block_number or
        (transaction.block_number == ^block_number and transaction.index < ^index)
    )
  end

  defp page_transaction(query, %PagingOptions{key: {index}}) do
    where(query, [transaction], transaction.index < ^index)
  end

  defp page_search_results(query, %PagingOptions{key: nil}), do: query

  # credo:disable-for-next-line
  defp page_search_results(query, %PagingOptions{
         key: {_address_hash, _tx_hash, _block_hash, holder_count, name, inserted_at, item_type}
       }) do
    where(
      query,
      [item],
      (item.holder_count < ^holder_count and item.type == ^item_type) or
        (item.holder_count == ^holder_count and item.name > ^name and item.type == ^item_type) or
        (item.holder_count == ^holder_count and item.name == ^name and item.inserted_at < ^inserted_at and
           item.type == ^item_type) or
        item.type != ^item_type
    )
  end

  def page_token_balances(query, %PagingOptions{key: nil}), do: query

  def page_token_balances(query, %PagingOptions{key: {value, address_hash}}) do
    where(
      query,
      [tb],
      tb.value < ^value or (tb.value == ^value and tb.address_hash < ^address_hash)
    )
  end

  def page_current_token_balances(query, %PagingOptions{key: nil}), do: query

  def page_current_token_balances(query, paging_options: %PagingOptions{key: nil}), do: query

  def page_current_token_balances(query, paging_options: %PagingOptions{key: {name, type, value}}) do
    where(
      query,
      [ctb, bt, t],
      ctb.value < ^value or (ctb.value == ^value and t.type < ^type) or
        (ctb.value == ^value and t.type == ^type and t.name < ^name)
    )
  end

  @doc """
  Ensures the following conditions are true:

    * excludes internal transactions of type call with no siblings in the
      transaction
    * includes internal transactions of type create, reward, or selfdestruct
      even when they are alone in the parent transaction

  """
  @spec where_transaction_has_multiple_internal_transactions(Ecto.Query.t()) :: Ecto.Query.t()
  def where_transaction_has_multiple_internal_transactions(query) do
    where(
      query,
      [internal_transaction, transaction],
      internal_transaction.type != ^:call or
        fragment(
          """
          EXISTS (SELECT sibling.*
          FROM internal_transactions AS sibling
          WHERE sibling.transaction_hash = ? AND sibling.index != ?
          )
          """,
          transaction.hash,
          internal_transaction.index
        )
    )
  end

  @doc """
  The current total number of coins minted minus verifiably burned coins.
  """
  @spec total_supply :: Decimal.t() | 0 | nil
  def total_supply do
    supply_module().total() || 0
  end

  @doc """
  The current number coins in the market for trading.
  """
  @spec circulating_supply :: non_neg_integer() | nil
  def circulating_supply do
    supply_module().circulating()
  end

  defp supply_module do
    Application.get_env(:explorer, :supply, Explorer.Chain.Supply.ExchangeRate)
  end

  @doc """
  Calls supply_for_days from the configured supply_module
  """
  def supply_for_days, do: supply_module().supply_for_days(MarketHistoryCache.recent_days_count())

  @doc """
  Streams a lists token contract addresses that haven't been cataloged.
  """
  @spec stream_uncataloged_token_contract_address_hashes(
          initial :: accumulator,
          reducer :: (entry :: Hash.Address.t(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_uncataloged_token_contract_address_hashes(initial, reducer) when is_function(reducer, 2) do
    query =
      from(
        token in Token,
        where: token.cataloged == false,
        select: token.contract_address_hash
      )

    Repo.stream_reduce(query, initial, reducer)
  end

  @spec stream_unfetched_token_instances(
          initial :: accumulator,
          reducer :: (entry :: map(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_token_instances(initial, reducer) when is_function(reducer, 2) do
    nft_tokens =
      from(
        token in Token,
        where: token.type == ^"ERC-721" or token.type == ^"ERC-1155",
        select: token.contract_address_hash
      )

    query =
      from(
        token_transfer in TokenTransfer,
        inner_join: token in subquery(nft_tokens),
        on: token.contract_address_hash == token_transfer.token_contract_address_hash,
        left_join: instance in Instance,
        on:
          token_transfer.token_id == instance.token_id and
            token_transfer.token_contract_address_hash == instance.token_contract_address_hash,
        where: is_nil(instance.token_id) and not is_nil(token_transfer.token_id),
        select: %{contract_address_hash: token_transfer.token_contract_address_hash, token_id: token_transfer.token_id}
      )

    distinct_query =
      from(
        q in subquery(query),
        distinct: [q.contract_address_hash, q.token_id]
      )

    Repo.stream_reduce(distinct_query, initial, reducer)
  end

  @doc """
  Streams a list of token contract addresses that have been cataloged.
  """
  @spec stream_cataloged_token_contract_address_hashes(
          initial :: accumulator,
          reducer :: (entry :: Hash.Address.t(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_cataloged_token_contract_address_hashes(initial, reducer, some_time_ago_updated \\ 2880)
      when is_function(reducer, 2) do
    some_time_ago_updated
    |> Token.cataloged_tokens()
    |> order_by(asc: :updated_at)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Returns a list of block numbers token transfer `t:Log.t/0`s that don't have an
  associated `t:TokenTransfer.t/0` record.
  """
  def uncataloged_token_transfer_block_numbers do
    query =
      from(l in Log,
        as: :log,
        where: l.first_topic == unquote(TokenTransfer.constant()),
        where:
          not exists(
            from(tf in TokenTransfer,
              where: tf.transaction_hash == parent_as(:log).transaction_hash,
              where: tf.log_index == parent_as(:log).index
            )
          ),
        select: l.block_number,
        distinct: l.block_number
      )

    Repo.stream_reduce(query, [], &[&1 | &2])
  end

  @doc """
  Returns a list of token addresses `t:Address.t/0`s that don't have an
  bridged property revealed.
  """
  def unprocessed_token_addresses_to_reveal_bridged_tokens do
    query =
      from(t in Token,
        where: is_nil(t.bridged),
        select: t.contract_address_hash
      )

    Repo.stream_reduce(query, [], &[&1 | &2])
  end

  @doc """
  Processes AMB tokens from mediators addresses provided
  """
  def process_amb_tokens do
    amb_bridge_mediators_var = Application.get_env(:block_scout_web, :amb_bridge_mediators)
    amb_bridge_mediators = (amb_bridge_mediators_var && String.split(amb_bridge_mediators_var, ",")) || []

    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    foreign_json_rpc = Application.get_env(:block_scout_web, :foreign_json_rpc)

    eth_call_foreign_json_rpc_named_arguments =
      compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, foreign_json_rpc)

    amb_bridge_mediators
    |> Enum.each(fn amb_bridge_mediator_hash ->
      with {:ok, bridge_contract_hash_resp} <-
             get_bridge_contract_hash(amb_bridge_mediator_hash, json_rpc_named_arguments),
           bridge_contract_hash <- decode_contract_address_hash_response(bridge_contract_hash_resp),
           {:ok, destination_chain_id_resp} <- get_destination_chain_id(bridge_contract_hash, json_rpc_named_arguments),
           foreign_chain_id <- decode_contract_integer_response(destination_chain_id_resp),
           {:ok, home_token_contract_hash_resp} <-
             get_erc677_token_hash(amb_bridge_mediator_hash, json_rpc_named_arguments),
           home_token_contract_hash_string <- decode_contract_address_hash_response(home_token_contract_hash_resp),
           {:ok, home_token_contract_hash} <- Chain.string_to_address_hash(home_token_contract_hash_string),
           {:ok, foreign_mediator_contract_hash_resp} <-
             get_foreign_mediator_contract_hash(amb_bridge_mediator_hash, json_rpc_named_arguments),
           foreign_mediator_contract_hash <- decode_contract_address_hash_response(foreign_mediator_contract_hash_resp),
           {:ok, foreign_token_contract_hash_resp} <-
             get_erc677_token_hash(foreign_mediator_contract_hash, eth_call_foreign_json_rpc_named_arguments),
           foreign_token_contract_hash_string <-
             decode_contract_address_hash_response(foreign_token_contract_hash_resp),
           {:ok, foreign_token_contract_hash} <- Chain.string_to_address_hash(foreign_token_contract_hash_string) do
        insert_bridged_token_metadata(home_token_contract_hash, %{
          foreign_chain_id: foreign_chain_id,
          foreign_token_address_hash: foreign_token_contract_hash,
          custom_metadata: nil,
          custom_cap: nil,
          lp_token: nil,
          type: "amb"
        })

        set_token_bridged_status(home_token_contract_hash, true)
      else
        result ->
          Logger.debug([
            "failed to fetch metadata for token bridged with AMB mediator #{amb_bridge_mediator_hash}",
            inspect(result)
          ])
      end
    end)

    :ok
  end

  @doc """
  Fetches bridged tokens metadata from OmniBridge.
  """
  def fetch_omni_bridged_tokens_metadata(token_addresses) do
    Enum.each(token_addresses, fn token_address_hash ->
      created_from_int_tx_success_query =
        from(
          it in InternalTransaction,
          inner_join: t in assoc(it, :transaction),
          where: it.created_contract_address_hash == ^token_address_hash,
          where: t.status == ^1
        )

      created_from_int_tx_success =
        created_from_int_tx_success_query
        |> Repo.one()

      created_from_tx_query =
        from(
          t in Transaction,
          where: t.created_contract_address_hash == ^token_address_hash
        )

      created_from_tx =
        created_from_tx_query
        |> Repo.all()
        |> Enum.count() > 0

      created_from_int_tx_query =
        from(
          it in InternalTransaction,
          where: it.created_contract_address_hash == ^token_address_hash
        )

      created_from_int_tx =
        created_from_int_tx_query
        |> Repo.all()
        |> Enum.count() > 0

      cond do
        created_from_tx ->
          set_token_bridged_status(token_address_hash, false)

        created_from_int_tx && !created_from_int_tx_success ->
          set_token_bridged_status(token_address_hash, false)

        created_from_int_tx && created_from_int_tx_success ->
          proceed_with_set_omni_status(token_address_hash, created_from_int_tx_success)

        true ->
          :ok
      end
    end)

    :ok
  end

  defp proceed_with_set_omni_status(token_address_hash, created_from_int_tx_success) do
    {:ok, eth_omni_status} =
      extract_omni_bridged_token_metadata_wrapper(
        token_address_hash,
        created_from_int_tx_success,
        :eth_omni_bridge_mediator
      )

    {:ok, bsc_omni_status} =
      if eth_omni_status do
        {:ok, false}
      else
        extract_omni_bridged_token_metadata_wrapper(
          token_address_hash,
          created_from_int_tx_success,
          :bsc_omni_bridge_mediator
        )
      end

    if !eth_omni_status && !bsc_omni_status do
      set_token_bridged_status(token_address_hash, false)
    end
  end

  defp extract_omni_bridged_token_metadata_wrapper(token_address_hash, created_from_int_tx_success, mediator) do
    omni_bridge_mediator = Application.get_env(:block_scout_web, mediator)
    %{transaction_hash: transaction_hash} = created_from_int_tx_success

    if omni_bridge_mediator && omni_bridge_mediator !== "" do
      {:ok, omni_bridge_mediator_hash} = Chain.string_to_address_hash(omni_bridge_mediator)

      created_by_amb_mediator_query =
        from(
          it in InternalTransaction,
          where: it.transaction_hash == ^transaction_hash,
          where: it.to_address_hash == ^omni_bridge_mediator_hash
        )

      created_by_amb_mediator =
        created_by_amb_mediator_query
        |> Repo.all()

      if Enum.count(created_by_amb_mediator) > 0 do
        extract_omni_bridged_token_metadata(
          token_address_hash,
          omni_bridge_mediator,
          omni_bridge_mediator_hash
        )

        {:ok, true}
      else
        {:ok, false}
      end
    else
      {:ok, false}
    end
  end

  defp extract_omni_bridged_token_metadata(token_address_hash, omni_bridge_mediator, omni_bridge_mediator_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    with {:ok, _} <-
           get_token_interfaces_version_signature(token_address_hash, json_rpc_named_arguments),
         {:ok, foreign_token_address_abi_encoded} <-
           get_foreign_token_address(omni_bridge_mediator, token_address_hash, json_rpc_named_arguments),
         {:ok, bridge_contract_hash_resp} <-
           get_bridge_contract_hash(omni_bridge_mediator_hash, json_rpc_named_arguments) do
      foreign_token_address_hash_string = decode_contract_address_hash_response(foreign_token_address_abi_encoded)
      {:ok, foreign_token_address_hash} = Chain.string_to_address_hash(foreign_token_address_hash_string)

      multi_token_bridge_hash_string = decode_contract_address_hash_response(bridge_contract_hash_resp)

      {:ok, foreign_chain_id_abi_encoded} =
        get_destination_chain_id(multi_token_bridge_hash_string, json_rpc_named_arguments)

      foreign_chain_id = decode_contract_integer_response(foreign_chain_id_abi_encoded)

      foreign_json_rpc = Application.get_env(:block_scout_web, :foreign_json_rpc)

      custom_metadata =
        get_bridged_token_custom_metadata(foreign_token_address_hash, json_rpc_named_arguments, foreign_json_rpc)

      insert_bridged_token_metadata(token_address_hash, %{
        foreign_chain_id: foreign_chain_id,
        foreign_token_address_hash: foreign_token_address_hash,
        custom_metadata: custom_metadata,
        custom_cap: nil,
        lp_token: nil,
        type: "omni"
      })

      set_token_bridged_status(token_address_hash, true)
    end
  end

  defp get_bridge_contract_hash(mediator_hash, json_rpc_named_arguments) do
    # keccak 256 from bridgeContract()
    bridge_contract_signature = "0xcd596583"

    perform_eth_call_request(bridge_contract_signature, mediator_hash, json_rpc_named_arguments)
  end

  defp get_erc677_token_hash(mediator_hash, json_rpc_named_arguments) do
    # keccak 256 from erc677token()
    erc677_token_signature = "0x18d8f9c9"

    perform_eth_call_request(erc677_token_signature, mediator_hash, json_rpc_named_arguments)
  end

  defp get_foreign_mediator_contract_hash(mediator_hash, json_rpc_named_arguments) do
    # keccak 256 from mediatorContractOnOtherSide()
    mediator_contract_on_other_side_signature = "0x871c0760"

    perform_eth_call_request(mediator_contract_on_other_side_signature, mediator_hash, json_rpc_named_arguments)
  end

  defp get_destination_chain_id(bridge_contract_hash, json_rpc_named_arguments) do
    # keccak 256 from destinationChainId()
    destination_chain_id_signature = "0xb0750611"

    perform_eth_call_request(destination_chain_id_signature, bridge_contract_hash, json_rpc_named_arguments)
  end

  defp get_token_interfaces_version_signature(token_address_hash, json_rpc_named_arguments) do
    # keccak 256 from getTokenInterfacesVersion()
    get_token_interfaces_version_signature = "0x859ba28c"

    perform_eth_call_request(get_token_interfaces_version_signature, token_address_hash, json_rpc_named_arguments)
  end

  defp get_foreign_token_address(omni_bridge_mediator, token_address_hash, json_rpc_named_arguments) do
    # keccak 256 from foreignTokenAddress(address)
    foreign_token_address_signature = "0x47ac7d6a"

    token_address_hash_abi_encoded =
      [token_address_hash.bytes]
      |> TypeEncoder.encode([:address])
      |> Base.encode16()

    foreign_token_address_method = foreign_token_address_signature <> token_address_hash_abi_encoded

    perform_eth_call_request(foreign_token_address_method, omni_bridge_mediator, json_rpc_named_arguments)
  end

  defp perform_eth_call_request(method, destination, json_rpc_named_arguments)
       when not is_nil(json_rpc_named_arguments) do
    method
    |> Contract.eth_call_request(destination, 1, nil, nil)
    |> json_rpc(json_rpc_named_arguments)
  end

  defp perform_eth_call_request(_method, _destination, json_rpc_named_arguments)
       when is_nil(json_rpc_named_arguments) do
    :error
  end

  def decode_contract_address_hash_response(resp) do
    case resp do
      "0x000000000000000000000000" <> address ->
        "0x" <> address

      _ ->
        nil
    end
  end

  def decode_contract_integer_response(resp) do
    case resp do
      "0x" <> integer_encoded ->
        {integer_value, _} = Integer.parse(integer_encoded, 16)
        integer_value

      _ ->
        nil
    end
  end

  defp set_token_bridged_status(token_address_hash, status) do
    case Repo.get(Token, token_address_hash) do
      %Explorer.Chain.Token{bridged: bridged} = target_token ->
        if !bridged do
          token = Changeset.change(target_token, bridged: status)

          Repo.update(token)
        end

      _ ->
        :ok
    end
  end

  defp insert_bridged_token_metadata(token_address_hash, %{
         foreign_chain_id: foreign_chain_id,
         foreign_token_address_hash: foreign_token_address_hash,
         custom_metadata: custom_metadata,
         custom_cap: custom_cap,
         lp_token: lp_token,
         type: type
       }) do
    target_token = Repo.get(Token, token_address_hash)

    if target_token do
      {:ok, _} =
        Repo.insert(
          %BridgedToken{
            home_token_contract_address_hash: token_address_hash,
            foreign_chain_id: foreign_chain_id,
            foreign_token_contract_address_hash: foreign_token_address_hash,
            custom_metadata: custom_metadata,
            custom_cap: custom_cap,
            lp_token: lp_token,
            type: type
          },
          on_conflict: :nothing
        )
    end
  end

  # Fetches custom metadata for bridged tokens from the node.
  # Currently, gets Balancer token composite tokens with their weights
  # from foreign chain
  defp get_bridged_token_custom_metadata(foreign_token_address_hash, json_rpc_named_arguments, foreign_json_rpc)
       when not is_nil(foreign_json_rpc) and foreign_json_rpc !== "" do
    eth_call_foreign_json_rpc_named_arguments =
      compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, foreign_json_rpc)

    balancer_custom_metadata(foreign_token_address_hash, eth_call_foreign_json_rpc_named_arguments) ||
      sushiswap_custom_metadata(foreign_token_address_hash, eth_call_foreign_json_rpc_named_arguments)
  end

  defp get_bridged_token_custom_metadata(_foreign_token_address_hash, _json_rpc_named_arguments, foreign_json_rpc)
       when is_nil(foreign_json_rpc) do
    nil
  end

  defp get_bridged_token_custom_metadata(_foreign_token_address_hash, _json_rpc_named_arguments, foreign_json_rpc)
       when foreign_json_rpc == "" do
    nil
  end

  defp balancer_custom_metadata(foreign_token_address_hash, eth_call_foreign_json_rpc_named_arguments) do
    # keccak 256 from getCurrentTokens()
    get_current_tokens_signature = "0xcc77828d"

    case get_current_tokens_signature
         |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
         |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
      {:ok, "0x"} ->
        nil

      {:ok, "0x" <> balancer_current_tokens_encoded} ->
        [balancer_current_tokens] =
          try do
            balancer_current_tokens_encoded
            |> Base.decode16!(case: :mixed)
            |> TypeDecoder.decode_raw([{:array, :address}])
          rescue
            _ -> []
          end

        bridged_token_custom_metadata =
          parse_bridged_token_custom_metadata(
            balancer_current_tokens,
            eth_call_foreign_json_rpc_named_arguments,
            foreign_token_address_hash
          )

        if is_map(bridged_token_custom_metadata) do
          tokens = Map.get(bridged_token_custom_metadata, :tokens)
          weights = Map.get(bridged_token_custom_metadata, :weights)

          if tokens == "" do
            nil
          else
            if weights !== "", do: "#{tokens} #{weights}", else: tokens
          end
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp sushiswap_custom_metadata(foreign_token_address_hash, eth_call_foreign_json_rpc_named_arguments) do
    # keccak 256 from token0()
    token0_signature = "0x0dfe1681"

    # keccak 256 from token1()
    token1_signature = "0xd21220a7"

    # keccak 256 from name()
    name_signature = "0x06fdde03"

    # keccak 256 from symbol()
    symbol_signature = "0x95d89b41"

    with {:ok, "0x" <> token0_encoded} <-
           token0_signature
           |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
         {:ok, "0x" <> token1_encoded} <-
           token1_signature
           |> Contract.eth_call_request(foreign_token_address_hash, 2, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
      token0_hash = parse_contract_response(token0_encoded, :address)
      token1_hash = parse_contract_response(token1_encoded, :address)

      if token0_hash && token1_hash do
        token0_hash_str = "0x" <> Base.encode16(token0_hash, case: :lower)
        token1_hash_str = "0x" <> Base.encode16(token1_hash, case: :lower)

        with {:ok, "0x" <> token0_name_encoded} <-
               name_signature
               |> Contract.eth_call_request(token0_hash_str, 1, nil, nil)
               |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
             {:ok, "0x" <> token1_name_encoded} <-
               name_signature
               |> Contract.eth_call_request(token1_hash_str, 2, nil, nil)
               |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
             {:ok, "0x" <> token0_symbol_encoded} <-
               symbol_signature
               |> Contract.eth_call_request(token0_hash_str, 1, nil, nil)
               |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
             {:ok, "0x" <> token1_symbol_encoded} <-
               symbol_signature
               |> Contract.eth_call_request(token1_hash_str, 2, nil, nil)
               |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
          token0_name = parse_contract_response(token0_name_encoded, :string, {:bytes, 32})
          token1_name = parse_contract_response(token1_name_encoded, :string, {:bytes, 32})
          token0_symbol = parse_contract_response(token0_symbol_encoded, :string, {:bytes, 32})
          token1_symbol = parse_contract_response(token1_symbol_encoded, :string, {:bytes, 32})

          "#{token0_name}/#{token1_name} (#{token0_symbol}/#{token1_symbol})"
        else
          _ ->
            nil
        end
      else
        nil
      end
    else
      _ ->
        nil
    end
  end

  def calc_lp_tokens_total_liqudity do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    foreign_json_rpc = Application.get_env(:block_scout_web, :foreign_json_rpc)
    bridged_mainnet_tokens_list = BridgedToken.get_unprocessed_mainnet_lp_tokens_list()

    Enum.each(bridged_mainnet_tokens_list, fn bridged_token ->
      case calc_sushiswap_lp_tokens_cap(
             bridged_token.home_token_contract_address_hash,
             bridged_token.foreign_token_contract_address_hash,
             json_rpc_named_arguments,
             foreign_json_rpc
           ) do
        {:ok, new_custom_cap} ->
          bridged_token
          |> Changeset.change(%{custom_cap: new_custom_cap, lp_token: true})
          |> Repo.update()

        {:error, :not_lp_token} ->
          bridged_token
          |> Changeset.change(%{lp_token: false})
          |> Repo.update()
      end
    end)

    Logger.debug(fn -> "Total liqudity fetched for LP tokens" end)
  end

  defp calc_sushiswap_lp_tokens_cap(
         home_token_contract_address_hash,
         foreign_token_address_hash,
         json_rpc_named_arguments,
         foreign_json_rpc
       ) do
    eth_call_foreign_json_rpc_named_arguments =
      compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, foreign_json_rpc)

    # keccak 256 from getReserves()
    get_reserves_signature = "0x0902f1ac"

    # keccak 256 from token0()
    token0_signature = "0x0dfe1681"

    # keccak 256 from token1()
    token1_signature = "0xd21220a7"

    # keccak 256 from totalSupply()
    total_supply_signature = "0x18160ddd"

    with {:ok, "0x" <> get_reserves_encoded} <-
           get_reserves_signature
           |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
         {:ok, "0x" <> home_token_total_supply_encoded} <-
           total_supply_signature
           |> Contract.eth_call_request(home_token_contract_address_hash, 1, nil, nil)
           |> json_rpc(json_rpc_named_arguments),
         [reserve0, reserve1, _] <-
           parse_contract_response(get_reserves_encoded, [{:uint, 112}, {:uint, 112}, {:uint, 32}]),
         {:ok, token0_cap_usd} <-
           get_lp_token_cap(
             home_token_total_supply_encoded,
             token0_signature,
             reserve0,
             foreign_token_address_hash,
             eth_call_foreign_json_rpc_named_arguments
           ),
         {:ok, token1_cap_usd} <-
           get_lp_token_cap(
             home_token_total_supply_encoded,
             token1_signature,
             reserve1,
             foreign_token_address_hash,
             eth_call_foreign_json_rpc_named_arguments
           ) do
      total_lp_cap = Decimal.add(token0_cap_usd, token1_cap_usd)
      {:ok, total_lp_cap}
    else
      _ ->
        {:error, :not_lp_token}
    end
  end

  defp get_lp_token_cap(
         home_token_total_supply_encoded,
         token_signature,
         reserve,
         foreign_token_address_hash,
         eth_call_foreign_json_rpc_named_arguments
       ) do
    # keccak 256 from decimals()
    decimals_signature = "0x313ce567"

    # keccak 256 from totalSupply()
    total_supply_signature = "0x18160ddd"

    home_token_total_supply =
      home_token_total_supply_encoded
      |> parse_contract_response({:uint, 256})
      |> Decimal.new()

    with {:ok, "0x" <> token_encoded} <-
           token_signature
           |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
      token_hash = parse_contract_response(token_encoded, :address)

      if token_hash do
        token_hash_str = "0x" <> Base.encode16(token_hash, case: :lower)

        with {:ok, "0x" <> token_decimals_encoded} <-
               decimals_signature
               |> Contract.eth_call_request(token_hash_str, 1, nil, nil)
               |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
             {:ok, "0x" <> foreign_token_total_supply_encoded} <-
               total_supply_signature
               |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
               |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
          token_decimals = parse_contract_response(token_decimals_encoded, {:uint, 256})

          foreign_token_total_supply =
            foreign_token_total_supply_encoded
            |> parse_contract_response({:uint, 256})
            |> Decimal.new()

          token_decimals_divider =
            10
            |> :math.pow(token_decimals)
            |> Decimal.from_float()

          token_cap =
            reserve
            |> Decimal.div(foreign_token_total_supply)
            |> Decimal.mult(home_token_total_supply)
            |> Decimal.div(token_decimals_divider)

          token_price = TokenExchangeRate.fetch_token_exchange_rate_by_address(token_hash_str)

          token_cap_usd =
            if token_price do
              token_price
              |> Decimal.mult(token_cap)
            else
              0
            end

          {:ok, token_cap_usd}
        end
      end
    end
  end

  defp parse_contract_response(abi_encoded_value, types) when is_list(types) do
    values =
      try do
        abi_encoded_value
        |> Base.decode16!(case: :mixed)
        |> TypeDecoder.decode_raw(types)
      rescue
        _ -> [nil]
      end

    values
  end

  defp parse_contract_response(abi_encoded_value, type, emergency_type \\ nil) do
    [value] =
      try do
        [res] = decode_contract_response(abi_encoded_value, type)

        [convert_binary_to_string(res, type)]
      rescue
        _ ->
          if emergency_type do
            try do
              [res] = decode_contract_response(abi_encoded_value, emergency_type)

              [convert_binary_to_string(res, emergency_type)]
            rescue
              _ ->
                [nil]
            end
          else
            [nil]
          end
      end

    value
  end

  defp decode_contract_response(abi_encoded_value, type) do
    abi_encoded_value
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw([type])
  end

  defp convert_binary_to_string(binary, type) do
    case type do
      {:bytes, _} ->
        ContractState.binary_to_string(binary)

      _ ->
        binary
    end
  end

  defp compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, foreign_json_rpc)
       when foreign_json_rpc != "" do
    {_, eth_call_foreign_json_rpc_named_arguments} =
      Keyword.get_and_update(json_rpc_named_arguments, :transport_options, fn transport_options ->
        {_, updated_transport_options} =
          update_transport_options_set_foreign_json_rpc(transport_options, foreign_json_rpc)

        {transport_options, updated_transport_options}
      end)

    eth_call_foreign_json_rpc_named_arguments
  end

  defp compose_foreign_json_rpc_named_arguments(_json_rpc_named_arguments, foreign_json_rpc)
       when foreign_json_rpc == "" do
    nil
  end

  defp compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, _foreign_json_rpc)
       when is_nil(json_rpc_named_arguments) do
    nil
  end

  defp update_transport_options_set_foreign_json_rpc(transport_options, foreign_json_rpc) do
    Keyword.get_and_update(transport_options, :method_to_url, fn method_to_url ->
      {_, updated_method_to_url} =
        Keyword.get_and_update(method_to_url, :eth_call, fn eth_call ->
          {eth_call, foreign_json_rpc}
        end)

      {method_to_url, updated_method_to_url}
    end)
  end

  defp parse_bridged_token_custom_metadata(
         balancer_current_tokens,
         eth_call_foreign_json_rpc_named_arguments,
         foreign_token_address_hash
       ) do
    balancer_current_tokens
    |> Enum.reduce(%{:tokens => "", :weights => ""}, fn balancer_token_bytes, balancer_tokens_weights ->
      balancer_token_hash_without_0x =
        balancer_token_bytes
        |> Base.encode16(case: :lower)

      balancer_token_hash = "0x" <> balancer_token_hash_without_0x

      # 95d89b41 = keccak256(symbol())
      symbol_signature = "0x95d89b41"

      case symbol_signature
           |> Contract.eth_call_request(balancer_token_hash, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
        {:ok, "0x" <> symbol_encoded} ->
          [symbol] =
            symbol_encoded
            |> Base.decode16!(case: :mixed)
            |> TypeDecoder.decode_raw([:string])

          # f1b8a9b7 = keccak256(getNormalizedWeight(address))
          get_normalized_weight_signature = "0xf1b8a9b7"

          get_normalized_weight_arg_abi_encoded =
            [balancer_token_bytes]
            |> TypeEncoder.encode([:address])
            |> Base.encode16(case: :lower)

          get_normalized_weight_abi_encoded = get_normalized_weight_signature <> get_normalized_weight_arg_abi_encoded

          get_normalized_weight_resp =
            get_normalized_weight_abi_encoded
            |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
            |> json_rpc(eth_call_foreign_json_rpc_named_arguments)

          parse_balancer_weights(get_normalized_weight_resp, balancer_tokens_weights, symbol)

        _ ->
          nil
      end
    end)
  end

  defp parse_balancer_weights(get_normalized_weight_resp, balancer_tokens_weights, symbol) do
    case get_normalized_weight_resp do
      {:ok, "0x" <> normalized_weight_encoded} ->
        [normalized_weight] =
          try do
            normalized_weight_encoded
            |> Base.decode16!(case: :mixed)
            |> TypeDecoder.decode_raw([{:uint, 256}])
          rescue
            _ ->
              []
          end

        normalized_weight_to_100_perc = calc_normalized_weight_to_100_perc(normalized_weight)

        normalized_weight_in_perc =
          normalized_weight_to_100_perc
          |> div(1_000_000_000_000_000_000)

        current_tokens = Map.get(balancer_tokens_weights, :tokens)
        current_weights = Map.get(balancer_tokens_weights, :weights)

        tokens_value = combine_tokens_value(current_tokens, symbol)
        weights_value = combine_weights_value(current_weights, normalized_weight_in_perc)

        %{:tokens => tokens_value, :weights => weights_value}

      _ ->
        nil
    end
  end

  defp calc_normalized_weight_to_100_perc(normalized_weight) do
    if normalized_weight, do: 100 * normalized_weight, else: 0
  end

  defp combine_tokens_value(current_tokens, symbol) do
    if current_tokens == "", do: symbol, else: current_tokens <> "/" <> symbol
  end

  defp combine_weights_value(current_weights, normalized_weight_in_perc) do
    if current_weights == "",
      do: "#{normalized_weight_in_perc}",
      else: current_weights <> "/" <> "#{normalized_weight_in_perc}"
  end

  @doc """
  Fetches a `t:Token.t/0` by an address hash.

  ## Options

      * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Token.t/0` has no associated record for that association,
      then the `t:Token.t/0` will not be included in the list.
  """
  @spec token_from_address_hash(Hash.Address.t(), [necessity_by_association_option]) ::
          {:ok, Token.t()} | {:error, :not_found}
  def token_from_address_hash(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = hash,
        options \\ []
      ) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query =
      from(
        t in Token,
        left_join: bt in BridgedToken,
        on: t.contract_address_hash == bt.home_token_contract_address_hash,
        where: t.contract_address_hash == ^hash,
        select: [t, bt]
      )

    query
    |> join_associations(necessity_by_association)
    |> preload(:contract_address)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      [%Token{} = token, %BridgedToken{} = bridged_token] ->
        foreign_token_contract_address_hash = Map.get(bridged_token, :foreign_token_contract_address_hash)
        foreign_chain_id = Map.get(bridged_token, :foreign_chain_id)
        custom_metadata = Map.get(bridged_token, :custom_metadata)
        custom_cap = Map.get(bridged_token, :custom_cap)

        extended_token =
          token
          |> Map.put(:foreign_token_contract_address_hash, foreign_token_contract_address_hash)
          |> Map.put(:foreign_chain_id, foreign_chain_id)
          |> Map.put(:custom_metadata, custom_metadata)
          |> Map.put(:custom_cap, custom_cap)

        {:ok, extended_token}

      [%Token{} = token, nil] ->
        {:ok, token}
    end
  end

  @spec fetch_token_transfers_from_token_hash(Hash.t(), [paging_options]) :: []
  def fetch_token_transfers_from_token_hash(token_address_hash, options \\ []) do
    TokenTransfer.fetch_token_transfers_from_token_hash(token_address_hash, options)
  end

  @spec fetch_token_transfers_from_token_hash_and_token_id(Hash.t(), binary(), [paging_options]) :: []
  def fetch_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options \\ []) do
    TokenTransfer.fetch_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options)
  end

  @spec count_token_transfers_from_token_hash(Hash.t()) :: non_neg_integer()
  def count_token_transfers_from_token_hash(token_address_hash) do
    TokenTransfer.count_token_transfers_from_token_hash(token_address_hash)
  end

  @spec count_token_transfers_from_token_hash_and_token_id(Hash.t(), binary()) :: non_neg_integer()
  def count_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id) do
    TokenTransfer.count_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id)
  end

  @spec transaction_has_token_transfers?(Hash.t()) :: boolean()
  def transaction_has_token_transfers?(transaction_hash) do
    query = from(tt in TokenTransfer, where: tt.transaction_hash == ^transaction_hash)

    Repo.exists?(query)
  end

  @spec address_has_rewards?(Address.t()) :: boolean()
  def address_has_rewards?(address_hash) do
    query = from(r in Reward, where: r.address_hash == ^address_hash)

    Repo.exists?(query)
  end

  @spec address_tokens_with_balance(Hash.Address.t(), [any()]) :: []
  def address_tokens_with_balance(address_hash, paging_options \\ []) do
    address_hash
    |> Address.Token.list_address_tokens_with_balance(paging_options)
    |> Repo.all()
  end

  @spec find_and_update_replaced_transactions([
          %{
            required(:nonce) => non_neg_integer,
            required(:from_address_hash) => Hash.Address.t(),
            required(:hash) => Hash.t()
          }
        ]) :: {integer(), nil | [term()]}
  def find_and_update_replaced_transactions(transactions, timeout \\ :infinity) do
    query =
      transactions
      |> Enum.reduce(
        Transaction,
        fn %{hash: hash, nonce: nonce, from_address_hash: from_address_hash}, query ->
          from(t in query,
            or_where:
              t.nonce == ^nonce and t.from_address_hash == ^from_address_hash and t.hash != ^hash and
                not is_nil(t.block_number)
          )
        end
      )
      # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
      |> order_by(asc: :hash)
      |> lock("FOR UPDATE")

    hashes = Enum.map(transactions, & &1.hash)

    transactions_to_update =
      from(pending in Transaction,
        join: duplicate in subquery(query),
        on: duplicate.nonce == pending.nonce,
        on: duplicate.from_address_hash == pending.from_address_hash,
        where: pending.hash in ^hashes and is_nil(pending.block_hash)
      )

    Repo.update_all(transactions_to_update, [set: [error: "dropped/replaced", status: :error]], timeout: timeout)
  end

  @spec update_replaced_transactions([
          %{
            required(:nonce) => non_neg_integer,
            required(:from_address_hash) => Hash.Address.t(),
            required(:block_hash) => Hash.Full.t()
          }
        ]) :: {integer(), nil | [term()]}
  def update_replaced_transactions(transactions, timeout \\ :infinity) do
    filters =
      transactions
      |> Enum.filter(fn transaction ->
        transaction.block_hash && transaction.nonce && transaction.from_address_hash
      end)
      |> Enum.map(fn transaction ->
        {transaction.nonce, transaction.from_address_hash}
      end)
      |> Enum.uniq()

    if Enum.empty?(filters) do
      {:ok, []}
    else
      query =
        filters
        |> Enum.reduce(Transaction, fn {nonce, from_address}, query ->
          from(t in query,
            or_where: t.nonce == ^nonce and t.from_address_hash == ^from_address and is_nil(t.block_hash)
          )
        end)
        # Enforce Transaction ShareLocks order (see docs: sharelocks.md)
        |> order_by(asc: :hash)
        |> lock("FOR UPDATE")

      Repo.update_all(
        from(t in Transaction, join: s in subquery(query), on: t.hash == s.hash),
        [set: [error: "dropped/replaced", status: :error]],
        timeout: timeout
      )
    end
  end

  @spec upsert_token_instance(map()) :: {:ok, Instance.t()} | {:error, Ecto.Changeset.t()}
  def upsert_token_instance(params) do
    changeset = Instance.changeset(%Instance{}, params)

    Repo.insert(changeset,
      on_conflict: :replace_all,
      conflict_target: [:token_id, :token_contract_address_hash]
    )
  end

  @doc """
  Update a new `t:Token.t/0` record.

  As part of updating token, an additional record is inserted for
  naming the address for reference if a name is provided for a token.
  """
  @spec update_token(Token.t(), map()) :: {:ok, Token.t()} | {:error, Ecto.Changeset.t()}
  def update_token(%Token{contract_address_hash: address_hash} = token, params \\ %{}) do
    token_changeset = Token.changeset(token, params)
    address_name_changeset = Address.Name.changeset(%Address.Name{}, Map.put(params, :address_hash, address_hash))

    stale_error_field = :contract_address_hash
    stale_error_message = "is up to date"

    token_opts = [
      on_conflict: Runner.Tokens.default_on_conflict(),
      conflict_target: :contract_address_hash,
      stale_error_field: stale_error_field,
      stale_error_message: stale_error_message
    ]

    address_name_opts = [on_conflict: :nothing, conflict_target: [:address_hash, :name]]

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    insert_result =
      Multi.new()
      |> Multi.run(
        :address_name,
        fn repo, _ ->
          {:ok, repo.insert(address_name_changeset, address_name_opts)}
        end
      )
      |> Multi.run(:token, fn repo, _ ->
        with {:error, %Changeset{errors: [{^stale_error_field, {^stale_error_message, [_]}}]}} <-
               repo.insert(token_changeset, token_opts) do
          # the original token passed into `update_token/2` as stale error means it is unchanged
          {:ok, token}
        end
      end)
      |> Repo.transaction()

    case insert_result do
      {:ok, %{token: token}} ->
        {:ok, token}

      {:error, :token, changeset, _} ->
        {:error, changeset}
    end
  end

  @spec fetch_last_token_balances(Hash.Address.t()) :: []
  def fetch_last_token_balances(address_hash) do
    address_hash
    |> CurrentTokenBalance.last_token_balances()
    |> Repo.all()
  end

  @spec fetch_last_token_balances(Hash.Address.t(), [paging_options]) :: []
  def fetch_last_token_balances(address_hash, paging_options) do
    address_hash
    |> CurrentTokenBalance.last_token_balances(paging_options)
    |> page_current_token_balances(paging_options)
    |> Repo.all()
  end

  @spec erc721_token_instance_from_token_id_and_token_address(binary(), Hash.Address.t()) ::
          {:ok, TokenTransfer.t()} | {:error, :not_found}
  def erc721_token_instance_from_token_id_and_token_address(token_id, token_contract_address) do
    query =
      from(tt in TokenTransfer,
        left_join: instance in Instance,
        on: tt.token_contract_address_hash == instance.token_contract_address_hash and tt.token_id == instance.token_id,
        where: tt.token_contract_address_hash == ^token_contract_address and tt.token_id == ^token_id,
        limit: 1,
        select: %{tt | instance: instance}
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      token_instance -> {:ok, token_instance}
    end
  end

  defp fetch_coin_balances(address_hash, paging_options) do
    address = Repo.get_by(Address, hash: address_hash)

    if contract?(address) do
      address_hash
      |> CoinBalance.fetch_coin_balances(paging_options)
    else
      address_hash
      |> CoinBalance.fetch_coin_balances_with_txs(paging_options)
    end
  end

  @spec fetch_last_token_balance(Hash.Address.t(), Hash.Address.t()) :: Decimal.t()
  def fetch_last_token_balance(address_hash, token_contract_address_hash) do
    address_hash
    |> CurrentTokenBalance.last_token_balance(token_contract_address_hash)
    |> Repo.one() || Decimal.new(0)
  end

  # @spec fetch_last_token_balance_1155(Hash.Address.t(), Hash.Address.t()) :: Decimal.t()
  def fetch_last_token_balance_1155(address_hash, token_contract_address_hash, token_id) do
    address_hash
    |> CurrentTokenBalance.last_token_balance_1155(token_contract_address_hash, token_id)
    |> Repo.one() || Decimal.new(0)
  end

  @spec address_to_coin_balances(Hash.Address.t(), [paging_options]) :: []
  def address_to_coin_balances(address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    balances_raw =
      address_hash
      |> fetch_coin_balances(paging_options)
      |> page_coin_balances(paging_options)
      |> Repo.all()

    if Enum.empty?(balances_raw) do
      balances_raw
    else
      balances_raw_filtered =
        balances_raw
        |> Enum.filter(fn balance -> balance.value end)

      min_block_number =
        balances_raw_filtered
        |> Enum.min_by(fn balance -> balance.block_number end, fn -> %{} end)
        |> Map.get(:block_number)

      max_block_number =
        balances_raw_filtered
        |> Enum.max_by(fn balance -> balance.block_number end, fn -> %{} end)
        |> Map.get(:block_number)

      min_block_timestamp = find_block_timestamp(min_block_number)
      max_block_timestamp = find_block_timestamp(max_block_number)

      min_block_unix_timestamp =
        min_block_timestamp
        |> Timex.to_unix()

      max_block_unix_timestamp =
        max_block_timestamp
        |> Timex.to_unix()

      blocks_delta = max_block_number - min_block_number

      balances_with_dates =
        if blocks_delta > 0 do
          balances_raw_filtered
          |> Enum.map(fn balance ->
            date =
              trunc(
                min_block_unix_timestamp +
                  (balance.block_number - min_block_number) * (max_block_unix_timestamp - min_block_unix_timestamp) /
                    blocks_delta
              )

            formatted_date = Timex.from_unix(date)
            %{balance | block_timestamp: formatted_date}
          end)
        else
          balances_raw_filtered
          |> Enum.map(fn balance ->
            date = min_block_unix_timestamp

            formatted_date = Timex.from_unix(date)
            %{balance | block_timestamp: formatted_date}
          end)
        end

      balances_with_dates
      |> Enum.sort(fn balance1, balance2 -> balance1.block_number >= balance2.block_number end)
    end
  end

  def get_coin_balance(address_hash, block_number) do
    query = CoinBalance.fetch_coin_balance(address_hash, block_number)

    Repo.one(query)
  end

  @spec address_to_balances_by_day(Hash.Address.t()) :: [balance_by_day]
  def address_to_balances_by_day(address_hash) do
    latest_block_timestamp =
      address_hash
      |> CoinBalance.last_coin_balance_timestamp()
      |> Repo.one()

    address_hash
    |> CoinBalanceDaily.balances_by_day()
    |> Repo.all()
    |> Enum.sort_by(fn %{date: d} -> {d.year, d.month, d.day} end)
    |> replace_last_value(latest_block_timestamp)
    |> normalize_balances_by_day()
  end

  # https://github.com/blockscout/blockscout/issues/2658
  defp replace_last_value(items, %{value: value, timestamp: timestamp}) do
    List.replace_at(items, -1, %{date: Date.convert!(timestamp, Calendar.ISO), value: value})
  end

  defp replace_last_value(items, _), do: items

  defp normalize_balances_by_day(balances_by_day) do
    result =
      balances_by_day
      |> Enum.filter(fn day -> day.value end)
      |> Enum.map(fn day -> Map.update!(day, :date, &to_string(&1)) end)
      |> Enum.map(fn day -> Map.update!(day, :value, &Wei.to(&1, :ether)) end)

    today = Date.to_string(NaiveDateTime.utc_now())

    if Enum.count(result) > 0 && !Enum.any?(result, fn map -> map[:date] == today end) do
      List.flatten([result | [%{date: today, value: List.last(result)[:value]}]])
    else
      result
    end
  end

  @spec fetch_token_holders_from_token_hash(Hash.Address.t(), [paging_options]) :: [TokenBalance.t()]
  def fetch_token_holders_from_token_hash(contract_address_hash, options \\ []) do
    contract_address_hash
    |> CurrentTokenBalance.token_holders_ordered_by_value(options)
    |> Repo.all()
  end

  def fetch_token_holders_from_token_hash_and_token_id(contract_address_hash, token_id, options \\ []) do
    contract_address_hash
    |> CurrentTokenBalance.token_holders_1155_by_token_id(token_id, options)
    |> Repo.all()
  end

  def token_id_1155_is_unique?(_, nil), do: false

  def token_id_1155_is_unique?(contract_address_hash, token_id) do
    result = contract_address_hash |> CurrentTokenBalance.token_balances_by_id_limit_2(token_id) |> Repo.all()

    if length(result) == 1 do
      Decimal.cmp(Enum.at(result, 0), 1) == :eq
    else
      false
    end
  end

  def get_token_ids_1155(contract_address_hash) do
    contract_address_hash
    |> CurrentTokenBalance.token_ids_query()
    |> Repo.all()
  end

  @spec count_token_holders_from_token_hash(Hash.Address.t()) :: non_neg_integer()
  def count_token_holders_from_token_hash(contract_address_hash) do
    query =
      from(ctb in CurrentTokenBalance.token_holders_query_for_count(contract_address_hash),
        select: fragment("COUNT(DISTINCT(address_hash))")
      )

    Repo.one!(query, timeout: :infinity)
  end

  @spec address_to_unique_tokens(Hash.Address.t(), [paging_options]) :: [TokenTransfer.t()]
  def address_to_unique_tokens(contract_address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    contract_address_hash
    |> TokenTransfer.address_to_unique_tokens()
    |> TokenTransfer.page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.all()
  end

  @spec data() :: Dataloader.Ecto.t()
  def data, do: DataloaderEcto.new(Repo)

  def list_decompiled_contracts(limit, offset, not_decompiled_with_version \\ nil) do
    query =
      from(
        address in Address,
        where: address.contract_code != <<>>,
        where: not is_nil(address.contract_code),
        where: address.decompiled == true,
        limit: ^limit,
        offset: ^offset,
        order_by: [asc: address.inserted_at],
        preload: [:smart_contract]
      )

    query
    |> reject_decompiled_with_version(not_decompiled_with_version)
    |> Repo.all()
  end

  @spec transaction_token_transfer_type(Transaction.t()) ::
          :erc20 | :erc721 | :erc1155 | :token_transfer | nil
  def transaction_token_transfer_type(
        %Transaction{
          status: :ok,
          created_contract_address_hash: nil,
          input: input,
          value: value
        } = transaction
      ) do
    zero_wei = %Wei{value: Decimal.new(0)}
    result = find_token_transfer_type(transaction, input, value)

    if is_nil(result) && Enum.count(transaction.token_transfers) > 0 && value == zero_wei,
      do: :token_transfer,
      else: result
  rescue
    _ -> nil
  end

  def transaction_token_transfer_type(_), do: nil

  defp find_token_transfer_type(transaction, input, value) do
    zero_wei = %Wei{value: Decimal.new(0)}

    # https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/token/ERC721/ERC721.sol#L35
    case {to_string(input), value} do
      # transferFrom(address,address,uint256)
      {"0x23b872dd" <> params, ^zero_wei} ->
        types = [:address, :address, {:uint, 256}]
        [from_address, to_address, _value] = decode_params(params, types)

        find_erc721_token_transfer(transaction.token_transfers, {from_address, to_address})

      # safeTransferFrom(address,address,uint256)
      {"0x42842e0e" <> params, ^zero_wei} ->
        types = [:address, :address, {:uint, 256}]
        [from_address, to_address, _value] = decode_params(params, types)

        find_erc721_token_transfer(transaction.token_transfers, {from_address, to_address})

      # safeTransferFrom(address,address,uint256,bytes)
      {"0xb88d4fde" <> params, ^zero_wei} ->
        types = [:address, :address, {:uint, 256}, :bytes]
        [from_address, to_address, _value, _data] = decode_params(params, types)

        find_erc721_token_transfer(transaction.token_transfers, {from_address, to_address})

      # safeTransferFrom(address,address,uint256,uint256,bytes)
      {"0xf242432a" <> params, ^zero_wei} ->
        types = [:address, :address, {:uint, 256}, {:uint, 256}, :bytes]
        [from_address, to_address, _id, _value, _data] = decode_params(params, types)

        find_erc1155_token_transfer(transaction.token_transfers, {from_address, to_address})

      # safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
      {"0x2eb2c2d6" <> params, ^zero_wei} ->
        types = [:address, :address, [{:uint, 256}], [{:uint, 256}], :bytes]
        [from_address, to_address, _ids, _values, _data] = decode_params(params, types)

        find_erc1155_token_transfer(transaction.token_transfers, {from_address, to_address})

      {"0xf907fc5b" <> _params, ^zero_wei} ->
        :erc20

      # check for ERC-20 or for old ERC-721, ERC-1155 token versions
      {unquote(TokenTransfer.transfer_function_signature()) <> params, ^zero_wei} ->
        types = [:address, {:uint, 256}]

        [address, value] = decode_params(params, types)

        decimal_value = Decimal.new(value)

        find_erc721_or_erc20_or_erc1155_token_transfer(transaction.token_transfers, {address, decimal_value})

      _ ->
        nil
    end
  end

  defp find_erc721_token_transfer(token_transfers, {from_address, to_address}) do
    token_transfer =
      Enum.find(token_transfers, fn token_transfer ->
        token_transfer.from_address_hash.bytes == from_address && token_transfer.to_address_hash.bytes == to_address
      end)

    if token_transfer, do: :erc721
  end

  defp find_erc1155_token_transfer(token_transfers, {from_address, to_address}) do
    token_transfer =
      Enum.find(token_transfers, fn token_transfer ->
        token_transfer.from_address_hash.bytes == from_address && token_transfer.to_address_hash.bytes == to_address
      end)

    if token_transfer, do: :erc1155
  end

  defp find_erc721_or_erc20_or_erc1155_token_transfer(token_transfers, {address, decimal_value}) do
    token_transfer =
      Enum.find(token_transfers, fn token_transfer ->
        token_transfer.to_address_hash.bytes == address && token_transfer.amount == decimal_value
      end)

    if token_transfer do
      case token_transfer.token do
        %Token{type: "ERC-20"} -> :erc20
        %Token{type: "ERC-721"} -> :erc721
        %Token{type: "ERC-1155"} -> :erc1155
        _ -> nil
      end
    else
      :erc20
    end
  end

  defp reject_decompiled_with_version(query, nil), do: query

  defp reject_decompiled_with_version(query, reject_version) do
    from(
      address in query,
      left_join: decompiled_smart_contract in assoc(address, :decompiled_smart_contracts),
      on: decompiled_smart_contract.decompiler_version == ^reject_version,
      where: is_nil(decompiled_smart_contract.address_hash)
    )
  end

  def list_verified_contracts(limit, offset) do
    query =
      from(
        smart_contract in SmartContract,
        order_by: [asc: smart_contract.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:address]
      )

    query
    |> Repo.all()
    |> Enum.map(fn smart_contract ->
      Map.put(smart_contract.address, :smart_contract, smart_contract)
    end)
  end

  def list_contracts(limit, offset) do
    query =
      from(
        address in Address,
        where: not is_nil(address.contract_code),
        preload: [:smart_contract],
        order_by: [asc: address.inserted_at],
        limit: ^limit,
        offset: ^offset
      )

    Repo.all(query)
  end

  def list_unordered_unverified_contracts(limit, offset) do
    query =
      from(
        address in Address,
        where: address.contract_code != <<>>,
        where: not is_nil(address.contract_code),
        where: fragment("? IS NOT TRUE", address.verified),
        limit: ^limit,
        offset: ^offset
      )

    query
    |> Repo.all()
    |> Enum.map(fn address ->
      %{address | smart_contract: nil}
    end)
  end

  def list_empty_contracts(limit, offset) do
    query =
      from(address in Address,
        where: address.contract_code == <<>>,
        preload: [:smart_contract, :decompiled_smart_contracts],
        order_by: [asc: address.inserted_at],
        limit: ^limit,
        offset: ^offset
      )

    Repo.all(query)
  end

  def list_unordered_not_decompiled_contracts(limit, offset) do
    query =
      from(
        address in Address,
        where: fragment("? IS NOT TRUE", address.verified),
        where: fragment("? IS NOT TRUE", address.decompiled),
        where: address.contract_code != <<>>,
        where: not is_nil(address.contract_code),
        limit: ^limit,
        offset: ^offset
      )

    query
    |> Repo.all()
    |> Enum.map(fn address ->
      %{address | smart_contract: nil}
    end)
  end

  @doc """
  Combined block reward from all the fees.
  """
  @spec block_combined_rewards(Block.t()) :: Wei.t()
  def block_combined_rewards(block) do
    {:ok, value} =
      block.rewards
      |> Enum.reduce(
        0,
        fn block_reward, acc ->
          {:ok, decimal} = Wei.dump(block_reward.reward)

          Decimal.add(decimal, acc)
        end
      )
      |> Wei.cast()

    value
  end

  @doc "Get staking pools from the DB"
  @spec staking_pools(
          filter :: :validator | :active | :inactive,
          paging_options :: PagingOptions.t() | :all,
          address_hash :: Hash.t() | nil,
          filter_banned :: boolean() | nil,
          filter_my :: boolean() | nil
        ) :: [map()]
  def staking_pools(
        filter,
        paging_options \\ @default_paging_options,
        address_hash \\ nil,
        filter_banned \\ false,
        filter_my \\ false
      ) do
    base_query =
      StakingPool
      |> where(is_deleted: false)
      |> staking_pool_filter(filter)
      |> staking_pools_paging_query(paging_options)

    delegator_query =
      if address_hash do
        base_query
        |> join(:left, [p], pd in StakingPoolsDelegator,
          on:
            p.staking_address_hash == pd.staking_address_hash and pd.address_hash == ^address_hash and
              not pd.is_deleted
        )
        |> select([p, pd], %{pool: p, delegator: pd})
      else
        base_query
        |> select([p], %{pool: p, delegator: nil})
      end

    banned_query =
      if filter_banned do
        where(delegator_query, is_banned: true)
      else
        delegator_query
      end

    filtered_query =
      if address_hash && filter_my do
        where(banned_query, [..., pd], not is_nil(pd))
      else
        banned_query
      end

    Repo.all(filtered_query)
  end

  defp staking_pools_paging_query(base_query, :all) do
    base_query
    |> order_by(asc: :staking_address_hash)
  end

  defp staking_pools_paging_query(base_query, paging_options) do
    paging_query =
      base_query
      |> limit(^paging_options.page_size)
      |> order_by(desc: :stakes_ratio, desc: :is_active, asc: :staking_address_hash)

    case paging_options.key do
      {value, address_hash} ->
        where(
          paging_query,
          [p],
          p.stakes_ratio < ^value or
            (p.stakes_ratio == ^value and p.staking_address_hash > ^address_hash)
        )

      _ ->
        paging_query
    end
  end

  @doc "Get count of staking pools from the DB"
  @spec staking_pools_count(filter :: :validator | :active | :inactive) :: integer
  def staking_pools_count(filter) do
    StakingPool
    |> where(is_deleted: false)
    |> staking_pool_filter(filter)
    |> Repo.aggregate(:count, :staking_address_hash)
  end

  @doc "Get sum of delegators count from the DB"
  @spec delegators_count_sum(filter :: :validator | :active | :inactive) :: integer
  def delegators_count_sum(filter) do
    StakingPool
    |> where(is_deleted: false)
    |> staking_pool_filter(filter)
    |> Repo.aggregate(:sum, :delegators_count)
  end

  @doc "Get sum of total staked amount from the DB"
  @spec total_staked_amount_sum(filter :: :validator | :active | :inactive) :: integer
  def total_staked_amount_sum(filter) do
    StakingPool
    |> where(is_deleted: false)
    |> staking_pool_filter(filter)
    |> Repo.aggregate(:sum, :total_staked_amount)
  end

  defp staking_pool_filter(query, :validator) do
    where(query, is_validator: true)
  end

  defp staking_pool_filter(query, :active) do
    where(query, is_active: true)
  end

  defp staking_pool_filter(query, :inactive) do
    where(query, is_active: false)
  end

  def staking_pool(staking_address_hash) do
    Repo.get_by(StakingPool, staking_address_hash: staking_address_hash)
  end

  def staking_pool_names(staking_addresses) do
    StakingPool
    |> where([p], p.staking_address_hash in ^staking_addresses and p.is_deleted == false)
    |> select([:staking_address_hash, :name])
    |> Repo.all()
  end

  def staking_pool_delegators(staking_address_hash, show_snapshotted_data) do
    query =
      from(
        d in StakingPoolsDelegator,
        where:
          d.staking_address_hash == ^staking_address_hash and
            (d.is_active == true or (^show_snapshotted_data and d.snapshotted_stake_amount > 0 and d.is_active != true)),
        order_by: [desc: d.stake_amount]
      )

    query
    |> Repo.all()
  end

  def staking_pool_snapshotted_delegator_data_for_apy do
    query =
      from(
        d in StakingPoolsDelegator,
        select: %{
          :staking_address_hash => fragment("DISTINCT ON (?) ?", d.staking_address_hash, d.staking_address_hash),
          :snapshotted_reward_ratio => d.snapshotted_reward_ratio,
          :snapshotted_stake_amount => d.snapshotted_stake_amount
        },
        where: d.staking_address_hash != d.address_hash and d.snapshotted_stake_amount > 0
      )

    query
    |> Repo.all()
  end

  def staking_pool_snapshotted_inactive_delegators_count(staking_address_hash) do
    query =
      from(
        d in StakingPoolsDelegator,
        where:
          d.staking_address_hash == ^staking_address_hash and
            d.snapshotted_stake_amount > 0 and
            d.is_active != true,
        select: fragment("count(*)")
      )

    query
    |> Repo.one()
  end

  def staking_pool_delegator(staking_address_hash, address_hash) do
    Repo.get_by(StakingPoolsDelegator,
      staking_address_hash: staking_address_hash,
      address_hash: address_hash,
      is_deleted: false
    )
  end

  def get_total_staked_and_ordered(""), do: nil

  def get_total_staked_and_ordered(address_hash) when is_binary(address_hash) do
    StakingPoolsDelegator
    |> where([delegator], delegator.address_hash == ^address_hash and not delegator.is_deleted)
    |> select([delegator], %{
      stake_amount: coalesce(sum(delegator.stake_amount), 0),
      ordered_withdraw: coalesce(sum(delegator.ordered_withdraw), 0)
    })
    |> Repo.one()
  end

  def get_total_staked_and_ordered(_), do: nil

  def bump_pending_blocks(pending_numbers) do
    update_query =
      from(
        b in Block,
        where: b.number in ^pending_numbers,
        select: b.hash,
        # ShareLocks order already enforced by `acquire_blocks` (see docs: sharelocks.md)
        update: [set: [update_count: b.update_count + 1]]
      )

    try do
      {_num, result} = Repo.update_all(update_query, [])

      Logger.debug(fn ->
        [
          "bumping following blocks: ",
          inspect(pending_numbers),
          " because of internal transaction issues"
        ]
      end)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error, pending_numbers: pending_numbers}}
    end
  end

  defp compute_votes do
    from(p in CeloVoters,
      inner_join: g in assoc(p, :group),
      group_by: p.voter_address_hash,
      select: %{
        result:
          fragment("sum(? + coalesce(? * ? / nullif(?,0), 0))", p.pending, p.units, g.active_votes, g.total_units),
        address: p.voter_address_hash
      }
    )
  end

  @spec get_celo_account(Hash.Address.t()) :: {:ok, CeloAccount.t()} | {:error, :not_found}
  def get_celo_account(address_hash) do
    get_signer_account(address_hash)
  end

  defp do_get_celo_account(address_hash) do
    query =
      from(account in CeloAccount,
        left_join: data in subquery(compute_votes()),
        on: data.address == account.address,
        where: account.address == ^address_hash,
        select_merge: %{
          active_gold: %{value: data.result}
        }
      )

    query
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      data ->
        {:ok, data}
    end
  end

  defp get_signer_account(address_hash) do
    query =
      from(s in CeloSigners,
        inner_join: a in CeloAccount,
        on: s.address == a.address,
        where: s.signer == ^address_hash,
        select: a
      )

    query
    |> Repo.one()
    |> case do
      nil -> do_get_celo_account(address_hash)
      data -> {:ok, data}
    end
  end

  def celo_validator_query do
    from(
      v in CeloValidator,
      left_join: t in assoc(v, :status),
      inner_join: a in assoc(v, :celo_account),
      left_join: data in subquery(compute_votes()),
      on: v.address == data.address,
      select_merge: %{
        last_online: t.last_online,
        last_elected: t.last_elected,
        name: a.name,
        url: a.url,
        locked_gold: a.locked_gold,
        nonvoting_locked_gold: a.nonvoting_locked_gold,
        attestations_requested: a.attestations_requested,
        attestations_fulfilled: a.attestations_fulfilled,
        active_gold: %{value: data.result},
        usd: a.usd
      }
    )
  end

  def get_celo_address(name) do
    query =
      from(p in CeloParams,
        where: p.name == ^name,
        select: p.address_value
      )

    query
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      data -> {:ok, data}
    end
  end

  def celo_validator_group_query do
    denominator =
      from(p in CeloParams,
        where: p.name == "numRegisteredValidators" or p.name == "maxElectableValidators",
        select: %{value: min(p.number_value)}
      )

    from(
      g in CeloValidatorGroup,
      inner_join: a in assoc(g, :celo_account),
      inner_join: b in assoc(g, :celo_accumulated_rewards),
      inner_join: total_locked_gold in CeloParams,
      where: total_locked_gold.name == "totalLockedGold",
      inner_join: denom in subquery(denominator),
      left_join: data in subquery(compute_votes()),
      on: g.address == data.address,
      select_merge: %{
        name: a.name,
        url: a.url,
        locked_gold: a.locked_gold,
        nonvoting_locked_gold: a.nonvoting_locked_gold,
        usd: a.usd,
        accumulated_active: b.active,
        accumulated_rewards: b.reward,
        rewards_ratio: b.ratio,
        active_gold: %{value: data.result},
        receivable_votes: (g.num_members + 1) * total_locked_gold.number_value / fragment("nullif(?,0)", denom.value)
      }
    )
  end

  @spec get_celo_validator(Hash.Address.t()) :: {:ok, CeloValidator.t()} | {:error, :not_found}
  def get_celo_validator(address_hash) do
    celo_validator_query()
    |> where([account], account.address == ^address_hash)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      data -> {:ok, data}
    end
  end

  def is_validator_address_signer_address?(address_hash) do
    CeloValidator
    |> where(signer_address_hash: ^address_hash)
    |> Repo.aggregate(:count, :address)
    |> case do
      0 -> false
      _ -> true
    end
  end

  @spec get_celo_validator_group(Hash.Address.t()) :: {:ok, CeloValidatorGroup.t()} | {:error, :not_found}
  def get_celo_validator_group(address_hash) do
    celo_validator_group_query()
    |> where([account], account.address == ^address_hash)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      data -> {:ok, data}
    end
  end

  def get_celo_validator_groups do
    celo_validator_group_query()
    |> Repo.all()
    |> case do
      nil -> {:error, :not_found}
      data -> {:ok, data}
    end
  end

  def get_celo_parameters do
    CeloParams
    |> Repo.all()
    |> case do
      nil -> {:error, :not_found}
      data -> {:ok, data}
    end
  end

  def get_celo_voters(group_address) do
    query =
      from(account in CeloVoters,
        where: account.group_address_hash == ^group_address,
        where: account.total > ^0
      )

    query
    |> Repo.all()
    |> case do
      nil -> []
      data -> data
    end
  end

  def get_celo_claims(address) do
    query =
      from(claim in CeloClaims,
        where: claim.address == ^address
      )

    query
    |> Repo.all()
    |> case do
      nil -> []
      data -> data
    end
  end

  def get_token_balance(address, symbol) do
    query =
      from(token in Token,
        join: balance in CurrentTokenBalance,
        where: token.symbol == ^symbol,
        where: balance.address_hash == ^address,
        where: balance.token_contract_address_hash == token.contract_address_hash,
        select: {balance.value}
      )

    query
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      {data} -> {:ok, %{value: data}}
    end
  end

  def get_latest_validating_block(address) do
    signer_query =
      from(validator in CeloValidator,
        select: validator.signer_address_hash,
        where: validator.address == ^address
      )

    signer_address =
      case Repo.one(signer_query) do
        nil -> address
        data -> data
      end

    direct_query =
      from(history in CeloValidatorHistory,
        where: history.online == true,
        where: history.address == ^signer_address,
        select: max(history.block_number)
      )

    direct_result =
      direct_query
      |> Repo.one()

    case direct_result do
      data when data != nil -> {:ok, data}
      _ -> {:error, :not_found}
    end
  end

  def get_latest_active_block(address) do
    signer_query =
      from(validator in CeloValidator,
        select: validator.signer_address_hash,
        where: validator.address == ^address
      )

    signer_address =
      case Repo.one(signer_query) do
        nil -> address
        data -> data
      end

    direct_query =
      from(history in CeloValidatorHistory,
        where: history.online == true,
        where: history.address == ^signer_address,
        select: max(history.block_number)
      )

    direct_result =
      direct_query
      |> Repo.one()

    case direct_result do
      data when data != nil -> {:ok, data}
      _ -> {:error, :not_found}
    end
  end

  def get_latest_history_block do
    query =
      from(history in CeloValidatorHistory,
        order_by: [desc: history.block_number],
        select: history.block_number
      )

    query
    |> Query.first()
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      data -> {:ok, data}
    end
  end

  def get_exchange_rate(symbol) do
    query =
      from(token in Token,
        join: rate in ExchangeRate,
        where: token.symbol == ^symbol,
        where: rate.token == token.contract_address_hash,
        select: {token, rate}
      )

    query
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      data -> {:ok, data}
    end
  end

  def query_leaderboard do
    # Computes the leaderboard score
    # For each account, the following is computed: CELO balance + cUSD balance * exchange rate
    # Each competitor can have several claimed accounts.
    # Final final score is the sum of account scores modified with the multiplier that is read from Google sheets
    result =
      SQL.query(Repo, """
        SELECT
          competitors.address,
          COALESCE(( SELECT name FROM celo_account WHERE address =  competitors.address), 'Unknown account'),
          (SUM(rate*token_balance+balance+locked_balance)+rate*COALESCE(old_usd,0)+COALESCE(old_gold,0))*
           (multiplier+COALESCE(attestation_multiplier,0)) AS score
        FROM exchange_rates, competitors, tokens, claims,
         ( SELECT claims.address AS c_address, claims.claimed_address AS address,
              COALESCE((SELECT value FROM address_current_token_balances, tokens WHERE claimed_address = address_hash
                        AND token_contract_address_hash = tokens.contract_address_hash AND tokens.symbol = 'cUSD'), 0) as token_balance,
              COALESCE((SELECT fetched_coin_balance FROM addresses WHERE claimed_address = hash), 0) as balance,
              COALESCE((SELECT locked_gold FROM celo_account WHERE claimed_address = address), 0) as locked_balance
            FROM claims ) AS get
        WHERE exchange_rates.token = tokens.contract_address_hash
        AND tokens.symbol = 'cUSD'
        AND claims.claimed_address = get.address
        AND claims.address = competitors.address
        AND claims.address = c_address
        GROUP BY competitors.address, rate, old_usd, old_gold, attestation_multiplier, multiplier
        ORDER BY score DESC
      """)

    case result do
      {:ok, %{rows: res}} -> {:ok, res}
      _ -> {:error, :not_found}
    end
  end

  defp with_decompiled_code_flag(query, _hash, false), do: query

  defp with_decompiled_code_flag(query, hash, true) do
    has_decompiled_code_query =
      from(decompiled_contract in DecompiledSmartContract,
        where: decompiled_contract.address_hash == ^hash,
        limit: 1,
        select: %{has_decompiled_code?: not is_nil(decompiled_contract.address_hash)}
      )

    from(
      address in query,
      left_join: decompiled_code in subquery(has_decompiled_code_query),
      select_merge: %{has_decompiled_code?: decompiled_code.has_decompiled_code?}
    )
  end

  defp decode_params(params, types) do
    params
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  def get_token_type(hash) do
    query =
      from(
        token in Token,
        where: token.contract_address_hash == ^hash,
        select: token.type
      )

    Repo.one(query)
  end

  @doc """
  Checks if an `t:Explorer.Chain.Address.t/0` with the given `hash` exists.

  Returns `:ok` if found

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.create_address(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> Explorer.Chain.check_address_exists(hash)
      :ok

  Returns `:not_found` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.check_address_exists(hash)
      :not_found

  """
  @spec check_address_exists(Hash.Address.t()) :: :ok | :not_found
  def check_address_exists(address_hash) do
    address_hash
    |> address_exists?()
    |> boolean_to_check_result()
  end

  @doc """
  Checks if an `t:Explorer.Chain.Address.t/0` with the given `hash` exists.

  Returns `true` if found

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.create_address(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> Explorer.Chain.address_exists?(hash)
      true

  Returns `false` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.address_exists?(hash)
      false

  """
  @spec address_exists?(Hash.Address.t()) :: boolean()
  def address_exists?(address_hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^address_hash
      )

    Repo.exists?(query)
  end

  @doc """
  Checks if it exists an `t:Explorer.Chain.Address.t/0` that has the provided
  `t:Explorer.Chain.Address.t/0` `hash` and a contract.

  Returns `:ok` if found and `:not_found` otherwise.
  """
  @spec check_contract_address_exists(Hash.Address.t()) :: :ok | :not_found
  def check_contract_address_exists(address_hash) do
    address_hash
    |> contract_address_exists?()
    |> boolean_to_check_result()
  end

  @doc """
  Checks if it exists an `t:Explorer.Chain.Address.t/0` that has the provided
  `t:Explorer.Chain.Address.t/0` `hash` and a contract.

  Returns `true` if found and `false` otherwise.
  """
  @spec contract_address_exists?(Hash.Address.t()) :: boolean()
  def contract_address_exists?(address_hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^address_hash and not is_nil(address.contract_code)
      )

    Repo.exists?(query)
  end

  @doc """
  Checks if it exists a `t:Explorer.Chain.DecompiledSmartContract.t/0` for the
  `t:Explorer.Chain.Address.t/0` with the provided `hash` and with the provided version.

  Returns `:ok` if found and `:not_found` otherwise.
  """
  @spec check_decompiled_contract_exists(Hash.Address.t(), String.t()) :: :ok | :not_found
  def check_decompiled_contract_exists(address_hash, version) do
    address_hash
    |> decompiled_contract_exists?(version)
    |> boolean_to_check_result()
  end

  @doc """
  Checks if it exists a `t:Explorer.Chain.DecompiledSmartContract.t/0` for the
  `t:Explorer.Chain.Address.t/0` with the provided `hash` and with the provided version.

  Returns `true` if found and `false` otherwise.
  """
  @spec decompiled_contract_exists?(Hash.Address.t(), String.t()) :: boolean()
  def decompiled_contract_exists?(address_hash, version) do
    query =
      from(contract in DecompiledSmartContract,
        where: contract.address_hash == ^address_hash and contract.decompiler_version == ^version
      )

    Repo.exists?(query)
  end

  @doc """
  Checks if it exists a verified `t:Explorer.Chain.SmartContract.t/0` for the
  `t:Explorer.Chain.Address.t/0` with the provided `hash`.

  Returns `:ok` if found and `:not_found` otherwise.
  """
  @spec check_verified_smart_contract_exists(Hash.Address.t()) :: :ok | :not_found
  def check_verified_smart_contract_exists(address_hash) do
    address_hash
    |> verified_smart_contract_exists?()
    |> boolean_to_check_result()
  end

  @doc """
  Checks if it exists a verified `t:Explorer.Chain.SmartContract.t/0` for the
  `t:Explorer.Chain.Address.t/0` with the provided `hash`.

  Returns `true` if found and `false` otherwise.
  """
  @spec verified_smart_contract_exists?(Hash.Address.t()) :: boolean()
  def verified_smart_contract_exists?(address_hash) do
    query =
      from(
        smart_contract in SmartContract,
        where: smart_contract.address_hash == ^address_hash
      )

    Repo.exists?(query)
  end

  @doc """
  Checks if a `t:Explorer.Chain.Transaction.t/0` with the given `hash` exists.

  Returns `:ok` if found

      iex> %Transaction{hash: hash} = insert(:transaction)
      iex> Explorer.Chain.check_transaction_exists(hash)
      :ok

  Returns `:not_found` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_transaction_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.check_transaction_exists(hash)
      :not_found
  """
  @spec check_transaction_exists(Hash.Full.t()) :: :ok | :not_found
  def check_transaction_exists(hash) do
    hash
    |> transaction_exists?()
    |> boolean_to_check_result()
  end

  @doc """
  Checks if a `t:Explorer.Chain.Transaction.t/0` with the given `hash` exists.

  Returns `true` if found

      iex> %Transaction{hash: hash} = insert(:transaction)
      iex> Explorer.Chain.transaction_exists?(hash)
      true

  Returns `false` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_transaction_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.transaction_exists?(hash)
      false
  """
  @spec transaction_exists?(Hash.Full.t()) :: boolean()
  def transaction_exists?(hash) do
    query =
      from(
        transaction in Transaction,
        where: transaction.hash == ^hash
      )

    Repo.exists?(query)
  end

  @doc """
  Checks if a `t:Explorer.Chain.Token.t/0` with the given `hash` exists.

  Returns `:ok` if found

      iex> address = insert(:address)
      iex> insert(:token, contract_address: address)
      iex> Explorer.Chain.check_token_exists(address.hash)
      :ok

  Returns `:not_found` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.check_token_exists(hash)
      :not_found
  """
  @spec check_token_exists(Hash.Address.t()) :: :ok | :not_found
  def check_token_exists(hash) do
    hash
    |> token_exists?()
    |> boolean_to_check_result()
  end

  @doc """
  Checks if a `t:Explorer.Chain.Token.t/0` with the given `hash` exists.

  Returns `true` if found

      iex> address = insert(:address)
      iex> insert(:token, contract_address: address)
      iex> Explorer.Chain.token_exists?(address.hash)
      true

  Returns `false` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.token_exists?(hash)
      false
  """
  @spec token_exists?(Hash.Address.t()) :: boolean()
  def token_exists?(hash) do
    query =
      from(
        token in Token,
        where: token.contract_address_hash == ^hash
      )

    Repo.exists?(query)
  end

  @doc """
  Checks if a `t:Explorer.Chain.TokenTransfer.t/0` with the given `hash` and `token_id` exists.

  Returns `:ok` if found

      iex> contract_address = insert(:address)
      iex> token_id = 10
      iex> insert(:token_transfer,
      ...>  from_address: contract_address,
      ...>  token_contract_address: contract_address,
      ...>  token_id: token_id
      ...> )
      iex> Explorer.Chain.check_erc721_token_instance_exists(token_id, contract_address.hash)
      :ok

  Returns `:not_found` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.check_erc721_token_instance_exists(10, hash)
      :not_found
  """
  @spec check_erc721_token_instance_exists(binary() | non_neg_integer(), Hash.Address.t()) :: :ok | :not_found
  def check_erc721_token_instance_exists(token_id, hash) do
    token_id
    |> erc721_token_instance_exist?(hash)
    |> boolean_to_check_result()
  end

  @doc """
  Checks if a `t:Explorer.Chain.TokenTransfer.t/0` with the given `hash` and `token_id` exists.

  Returns `true` if found

      iex> contract_address = insert(:address)
      iex> token_id = 10
      iex> insert(:token_transfer,
      ...>  from_address: contract_address,
      ...>  token_contract_address: contract_address,
      ...>  token_id: token_id
      ...> )
      iex> Explorer.Chain.erc721_token_instance_exist?(token_id, contract_address.hash)
      true

  Returns `false` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.erc721_token_instance_exist?(10, hash)
      false
  """
  @spec erc721_token_instance_exist?(binary() | non_neg_integer(), Hash.Address.t()) :: boolean()
  def erc721_token_instance_exist?(token_id, hash) do
    query =
      from(tt in TokenTransfer,
        where: tt.token_contract_address_hash == ^hash and tt.token_id == ^token_id
      )

    Repo.exists?(query)
  end

  defp boolean_to_check_result(true), do: :ok

  defp boolean_to_check_result(false), do: :not_found

  @spec fetch_number_of_locks :: non_neg_integer()
  def fetch_number_of_locks do
    result =
      SQL.query(Repo, """
      SELECT COUNT(*) FROM (SELECT blocked_locks.pid     AS blocked_pid,
           blocked_activity.usename  AS blocked_user,
           blocking_locks.pid     AS blocking_pid,
           blocking_activity.usename AS blocking_user,
           blocked_activity.query    AS blocked_statement,
           blocking_activity.query   AS current_statement_in_blocking_process
      FROM  pg_catalog.pg_locks         blocked_locks
      JOIN pg_catalog.pg_stat_activity blocked_activity  ON blocked_activity.pid = blocked_locks.pid
      JOIN pg_catalog.pg_locks         blocking_locks
          ON blocking_locks.locktype = blocked_locks.locktype
          AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
          AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
          AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
          AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
          AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
          AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
          AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
          AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
          AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
          AND blocking_locks.pid != blocked_locks.pid
      JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
      WHERE NOT blocked_locks.GRANTED) a;
      """)

    case result do
      {:ok, %Postgrex.Result{rows: [[rows]]}} -> rows
      _ -> 0
    end
  end

  @spec fetch_number_of_dead_locks :: non_neg_integer()
  def fetch_number_of_dead_locks do
    database =
      :explorer
      |> Application.get_env(Explorer.Repo)
      |> Keyword.get(:database)

    result =
      SQL.query(
        Repo,
        """
        SELECT deadlocks FROM pg_stat_database where datname = $1;
        """,
        [database]
      )

    case result do
      {:ok, %Postgrex.Result{rows: [[rows]]}} -> rows
      _ -> 0
    end
  end

  @spec fetch_name_and_duration_of_longest_query :: non_neg_integer()
  def fetch_name_and_duration_of_longest_query do
    result =
      SQL.query(Repo, """
        SELECT query, NOW() - xact_start AS duration FROM pg_stat_activity
        WHERE state IN ('idle in transaction', 'active') ORDER BY now() - xact_start DESC LIMIT 1;
      """)

    {:ok, longest_query_map} = result

    case Map.fetch(longest_query_map, :rows) do
      {:ok, [[_, longest_query_duration]]} when not is_nil(longest_query_duration) -> longest_query_duration.secs
      _ -> 0
    end
  end

  @doc """
  Fetches the first trace from the Parity trace URL.
  """
  def fetch_first_trace(transactions_params, json_rpc_named_arguments) do
    case EthereumJSONRPC.fetch_first_trace(transactions_params, json_rpc_named_arguments) do
      {:ok, [%{first_trace: first_trace, block_hash: block_hash, json_rpc_named_arguments: json_rpc_named_arguments}]} ->
        format_tx_first_trace(first_trace, block_hash, json_rpc_named_arguments)

      {:error, error} ->
        {:error, error}

      :ignore ->
        :ignore
    end
  end

  def combine_proxy_implementation_abi(proxy_address_hash, abi) when not is_nil(abi) do
    implementation_abi = get_implementation_abi_from_proxy(proxy_address_hash, abi)
    if Enum.empty?(implementation_abi), do: abi, else: implementation_abi ++ abi
  end

  def combine_proxy_implementation_abi(_, abi) when is_nil(abi) do
    []
  end

  def proxy_contract?(_address_hash, abi) when abi in [nil, false, []], do: false

  def proxy_contract?(address_hash, abi) when not is_nil(abi) do
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        Map.get(method, "name") == "implementation" ||
          master_copy_pattern?(method)
      end)

    if implementation_method_abi ||
         get_implementation_address_hash_eip_1967(address_hash) !== "0x0000000000000000000000000000000000000000",
       do: true,
       else: false
  end

  def gnosis_safe_contract?(abi) when not is_nil(abi) do
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        master_copy_pattern?(method)
      end)

    if implementation_method_abi, do: true, else: false
  end

  def gnosis_safe_contract?(abi) when is_nil(abi), do: false

  def get_implementation_address_hash(proxy_address_hash, abi)
      when not is_nil(proxy_address_hash) and not is_nil(abi) do
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        Map.get(method, "name") == "implementation" && Map.get(method, "stateMutability") == "view"
      end)

    master_copy_method_abi =
      abi
      |> Enum.find(fn method ->
        master_copy_pattern?(method)
      end)

    cond do
      implementation_method_abi ->
        get_implementation_address_hash_basic(proxy_address_hash, abi)

      master_copy_method_abi ->
        get_implementation_address_hash_from_master_copy_pattern(proxy_address_hash)

      true ->
        get_implementation_address_hash_eip_1967(proxy_address_hash)
    end
  end

  def get_implementation_address_hash(proxy_address_hash, abi) when is_nil(proxy_address_hash) or is_nil(abi) do
    nil
  end

  defp get_implementation_address_hash_eip_1967(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    # https://eips.ethereum.org/EIPS/eip-1967
    storage_slot_logic_contract_address = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

    {_status, implementation_address} =
      case Contract.eth_get_storage_at_request(
             proxy_address_hash,
             storage_slot_logic_contract_address,
             nil,
             json_rpc_named_arguments
           ) do
        {:ok, empty_address}
        when empty_address in ["0x", "0x0000000000000000000000000000000000000000000000000000000000000000"] ->
          fetch_beacon_proxy_implementation(proxy_address_hash, json_rpc_named_arguments)

        {:ok, implementation_logic_address} ->
          {:ok, implementation_logic_address}

        {:error, _} ->
          {:ok, "0x"}
      end

    abi_decode_address_output(implementation_address)
  end

  # changes requested by https://github.com/blockscout/blockscout/issues/4770
  # for support BeaconProxy pattern
  defp fetch_beacon_proxy_implementation(proxy_address_hash, json_rpc_named_arguments) do
    # https://eips.ethereum.org/EIPS/eip-1967
    storage_slot_beacon_contract_address = "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"

    implementation_method_abi = [
      %{
        "type" => "function",
        "stateMutability" => "view",
        "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
        "name" => "implementation",
        "inputs" => []
      }
    ]

    case Contract.eth_get_storage_at_request(
           proxy_address_hash,
           storage_slot_beacon_contract_address,
           nil,
           json_rpc_named_arguments
         ) do
      {:ok, empty_address}
      when empty_address in ["0x", "0x0000000000000000000000000000000000000000000000000000000000000000"] ->
        {:ok, "0x"}

      {:ok, beacon_contract_address} ->
        case beacon_contract_address
             |> abi_decode_address_output()
             |> get_implementation_address_hash_basic(implementation_method_abi) do
          <<implementation_address::binary-size(42)>> ->
            {:ok, implementation_address}

          _ ->
            {:ok, beacon_contract_address}
        end

      {:error, _} ->
        {:ok, "0x"}
    end
  end

  defp get_implementation_address_hash_basic(proxy_address_hash, abi) do
    # 5c60da1b = keccak256(implementation())
    implementation_address =
      case Reader.query_contract(
             proxy_address_hash,
             abi,
             %{
               "5c60da1b" => []
             },
             false
           ) do
        %{"5c60da1b" => {:ok, [result]}} -> result
        _ -> nil
      end

    address_to_hex(implementation_address)
  end

  defp get_implementation_address_hash_from_master_copy_pattern(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    master_copy_storage_pointer = "0x0"

    {:ok, implementation_address} =
      Contract.eth_get_storage_at_request(
        proxy_address_hash,
        master_copy_storage_pointer,
        nil,
        json_rpc_named_arguments
      )

    abi_decode_address_output(implementation_address)
  end

  defp master_copy_pattern?(method) do
    Map.get(method, "type") == "constructor" &&
      method
      |> Enum.find(fn item ->
        case item do
          {"inputs", inputs} ->
            master_copy_input?(inputs)

          _ ->
            false
        end
      end)
  end

  defp master_copy_input?(inputs) do
    inputs
    |> Enum.find(fn input ->
      Map.get(input, "name") == "_masterCopy"
    end)
  end

  defp abi_decode_address_output(nil), do: nil

  defp abi_decode_address_output("0x"), do: @burn_address_hash_str

  defp abi_decode_address_output(address) when is_binary(address) do
    if String.length(address) > 42 do
      "0x" <> String.slice(address, -40, 40)
    else
      address
    end
  end

  defp abi_decode_address_output(_), do: nil

  defp address_to_hex(address) do
    if address do
      if String.starts_with?(address, "0x") do
        address
      else
        "0x" <> Base.encode16(address, case: :lower)
      end
    end
  end

  def get_implementation_abi(implementation_address_hash_string) when not is_nil(implementation_address_hash_string) do
    case Chain.string_to_address_hash(implementation_address_hash_string) do
      {:ok, implementation_address_hash} ->
        implementation_smart_contract =
          implementation_address_hash
          |> Chain.address_hash_to_smart_contract()

        if implementation_smart_contract do
          implementation_smart_contract
          |> Map.get(:abi)
        else
          []
        end

      _ ->
        []
    end
  end

  def get_implementation_abi(implementation_address_hash_string) when is_nil(implementation_address_hash_string) do
    []
  end

  def get_implementation_abi_from_proxy(proxy_address_hash, abi)
      when not is_nil(proxy_address_hash) and not is_nil(abi) do
    if proxy_contract?(proxy_address_hash, abi) do
      implementation_address_hash_string = get_implementation_address_hash(proxy_address_hash, abi)

      if implementation_address_hash_string do
        get_implementation_abi(implementation_address_hash_string)
      else
        []
      end
    else
      []
    end
  end

  def get_implementation_abi_from_proxy(proxy_address_hash, abi) when is_nil(proxy_address_hash) or is_nil(abi) do
    []
  end

  defp format_tx_first_trace(first_trace, block_hash, json_rpc_named_arguments) do
    {:ok, to_address_hash} =
      if Map.has_key?(first_trace, :to_address_hash) do
        Chain.string_to_address_hash(first_trace.to_address_hash)
      else
        {:ok, nil}
      end

    {:ok, from_address_hash} = Chain.string_to_address_hash(first_trace.from_address_hash)

    {:ok, created_contract_address_hash} =
      if Map.has_key?(first_trace, :created_contract_address_hash) do
        Chain.string_to_address_hash(first_trace.created_contract_address_hash)
      else
        {:ok, nil}
      end

    {:ok, transaction_hash} = Chain.string_to_transaction_hash(first_trace.transaction_hash)

    {:ok, call_type} =
      if Map.has_key?(first_trace, :call_type) do
        CallType.load(first_trace.call_type)
      else
        {:ok, nil}
      end

    {:ok, type} = Type.load(first_trace.type)

    {:ok, input} =
      if Map.has_key?(first_trace, :input) do
        Data.cast(first_trace.input)
      else
        {:ok, nil}
      end

    {:ok, output} =
      if Map.has_key?(first_trace, :output) do
        Data.cast(first_trace.output)
      else
        {:ok, nil}
      end

    {:ok, created_contract_code} =
      if Map.has_key?(first_trace, :created_contract_code) do
        Data.cast(first_trace.created_contract_code)
      else
        {:ok, nil}
      end

    {:ok, init} =
      if Map.has_key?(first_trace, :init) do
        Data.cast(first_trace.init)
      else
        {:ok, nil}
      end

    block_index =
      get_block_index(%{
        transaction_index: first_trace.transaction_index,
        transaction_hash: first_trace.transaction_hash,
        block_number: first_trace.block_number,
        json_rpc_named_arguments: json_rpc_named_arguments
      })

    value = %Wei{value: Decimal.new(first_trace.value)}

    first_trace_formatted =
      first_trace
      |> Map.merge(%{
        block_index: block_index,
        block_hash: block_hash,
        call_type: call_type,
        to_address_hash: to_address_hash,
        created_contract_address_hash: created_contract_address_hash,
        from_address_hash: from_address_hash,
        input: input,
        output: output,
        created_contract_code: created_contract_code,
        init: init,
        transaction_hash: transaction_hash,
        type: type,
        value: value
      })

    {:ok, [first_trace_formatted]}
  end

  defp get_block_index(%{
         transaction_index: transaction_index,
         transaction_hash: transaction_hash,
         block_number: block_number,
         json_rpc_named_arguments: json_rpc_named_arguments
       }) do
    if transaction_index == 0 do
      0
    else
      {:ok, traces} = fetch_block_internal_transactions([block_number], json_rpc_named_arguments)

      sorted_traces =
        traces
        |> Enum.sort_by(&{&1.transaction_index, &1.index})
        |> Enum.with_index()

      {_, block_index} =
        sorted_traces
        |> Enum.find({nil, -1}, fn {trace, _} ->
          trace.transaction_index == transaction_index &&
            trace.transaction_hash == transaction_hash
        end)

      block_index
    end
  end

  defp find_block_timestamp(number) do
    Block
    |> where([b], b.number == ^number)
    |> select([b], b.timestamp)
    |> limit(1)
    |> Repo.one()
  end

  def bridged_tokens_enabled? do
    eth_omni_bridge_mediator = Application.get_env(:block_scout_web, :eth_omni_bridge_mediator)
    bsc_omni_bridge_mediator = Application.get_env(:block_scout_web, :bsc_omni_bridge_mediator)

    (eth_omni_bridge_mediator && eth_omni_bridge_mediator !== "") ||
      (bsc_omni_bridge_mediator && bsc_omni_bridge_mediator !== "")
  end

  def bridged_tokens_eth_enabled? do
    eth_omni_bridge_mediator = Application.get_env(:block_scout_web, :eth_omni_bridge_mediator)

    eth_omni_bridge_mediator && eth_omni_bridge_mediator !== ""
  end

  def bridged_tokens_bsc_enabled? do
    bsc_omni_bridge_mediator = Application.get_env(:block_scout_web, :bsc_omni_bridge_mediator)

    bsc_omni_bridge_mediator && bsc_omni_bridge_mediator !== ""
  end

  def chain_id_display_name(nil), do: ""

  def chain_id_display_name(chain_id) do
    chain_id_int =
      if is_integer(chain_id) do
        chain_id
      else
        chain_id
        |> Decimal.to_integer()
      end

    case chain_id_int do
      1 -> "eth"
      56 -> "bsc"
      _ -> ""
    end
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
            tx_stats in TransactionStats,
            where: tx_stats.date == ^date,
            select: tx_stats.total_fee
          )

        total_fees = Repo.one(query)
        {:ok, total_fees}

      _ ->
        {:error, "An incorrect input date provided. It should be in ISO 8601 format (yyyy-mm-dd)."}
    end
  end

  @spec get_token_transfer_type(TokenTransfer.t()) ::
          :token_burning | :token_minting | :token_spawning | :token_transfer
  def get_token_transfer_type(transfer) do
    {:ok, burn_address_hash} = Chain.string_to_address_hash(@burn_address_hash_str)

    cond do
      transfer.to_address_hash == burn_address_hash && transfer.from_address_hash !== burn_address_hash ->
        :token_burning

      transfer.to_address_hash !== burn_address_hash && transfer.from_address_hash == burn_address_hash ->
        :token_minting

      transfer.to_address_hash == burn_address_hash && transfer.from_address_hash == burn_address_hash ->
        :token_spawning

      true ->
        :token_transfer
    end
  end

  @doc """
  Returns the total amount of CELO that is unlocked and can't or hasn't yet been withdrawn.
  Details at: https://docs.celo.org/celo-codebase/protocol/proof-of-stake/locked-gold#unlocking-period
  """
  @spec fetch_sum_celo_unlocked() :: Wei.t()
  def fetch_sum_celo_unlocked do
    query =
      from(w in CeloUnlocked,
        select: sum(w.amount)
      )

    query
    |> Repo.one()
    |> case do
      nil -> %Wei{value: Decimal.new(0)}
      sum -> sum
    end
  end

  @doc """
  Returns the total amount of CELO that is unlocked and hasn't yet been withdrawn.
  """
  @spec fetch_sum_available_celo_unlocked() :: Wei.t()
  def fetch_sum_available_celo_unlocked do
    query =
      from(w in CeloUnlocked,
        select: sum(w.amount),
        where: w.available <= fragment("NOW()")
      )

    query
    |> Repo.one()
    |> case do
      nil -> %Wei{value: Decimal.new(0)}
      sum -> sum
    end
  end

  @doc """
  Deletes unlocked CELO when passed the address and the amount
  """
  @spec delete_celo_unlocked(Hash.t(), non_neg_integer()) :: {integer(), nil | [term()]}
  def delete_celo_unlocked(address, amount) do
    query =
      from(celo_unlocked in CeloUnlocked,
        where: celo_unlocked.account_address == ^address and celo_unlocked.amount == ^amount
      )

    Repo.delete_all(query)
  end

  @doc """
  Insert unlocked CELO when passed the address, the amount and when the amount will be available as a unix timestamp
  """
  @spec insert_celo_unlocked(Hash.t(), non_neg_integer(), non_neg_integer()) :: {integer(), nil | [term()]}
  def insert_celo_unlocked(address, amount, available) do
    changeset =
      CeloUnlocked.changeset(%CeloUnlocked{}, %{
        account_address: address,
        amount: amount,
        available: DateTime.from_unix!(available, :second)
      })

    Repo.insert(changeset)
  end

  @spec get_token_icon_url_by(String.t(), String.t()) :: String.t() | nil
  def get_token_icon_url_by(chain_id, address_hash) do
    chain_name =
      case chain_id do
        "1" ->
          "ethereum"

        "99" ->
          "poa"

        "100" ->
          "xdai"

        _ ->
          nil
      end

    if chain_name do
      try_url =
        "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/#{chain_name}/assets/#{address_hash}/logo.png"

      try_url
    else
      nil
    end
  end

  defp from_block(options) do
    Keyword.get(options, :from_block) || nil
  end

  def to_block(options) do
    Keyword.get(options, :to_block) || nil
  end

  def convert_date_to_min_block(date_str) do
    date_format = "%Y-%m-%d"

    {:ok, date} =
      date_str
      |> Timex.parse(date_format, :strftime)

    {:ok, day_before} =
      date
      |> Timex.shift(days: -1)
      |> Timex.format(date_format, :strftime)

    convert_date_to_max_block(day_before)
  end

  def convert_date_to_max_block(date) do
    {:ok, from} =
      date
      |> Date.from_iso8601!()
      |> NaiveDateTime.new(~T[00:00:00])

    next_day = from |> NaiveDateTime.add(:timer.hours(24), :millisecond)

    block_query =
      from(b in Block,
        select: %{max: max(b.timestamp), number: b.number},
        where: fragment("? BETWEEN ? AND ?", b.timestamp, ^from, ^next_day),
        group_by: b.number
      )

    query = from(b in subquery(block_query), select: max(b.number))

    query
    |> Repo.one()
  end

  def pending_withdrawals_for_account(account_address) do
    query =
      from(unlocked in CeloUnlocked,
        select: %{
          amount: unlocked.amount,
          available: unlocked.available
        },
        where: unlocked.account_address == ^account_address
      )

    Repo.all(query, timeout: :infinity)
  end
end
