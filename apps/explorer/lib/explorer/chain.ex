defmodule Explorer.Chain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query,
    only: [
      from: 2,
      join: 4,
      limit: 2,
      lock: 2,
      order_by: 2,
      order_by: 3,
      offset: 2,
      preload: 2,
      select: 2,
      subquery: 1,
      union: 2,
      union_all: 2,
      where: 2,
      where: 3,
      select: 3
    ]

  import EthereumJSONRPC, only: [integer_to_quantity: 1, fetch_block_internal_transactions: 2]

  alias ABI.TypeDecoder
  alias Ecto.Adapters.SQL
  alias Ecto.{Changeset, Multi}

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
    Data,
    DecompiledSmartContract,
    Hash,
    Import,
    InternalTransaction,
    Log,
    PendingBlockOperation,
    SmartContract,
    StakingPool,
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
    TransactionCount,
    Transactions,
    Uncles
  }

  alias Explorer.Chain.Import.Runner
  alias Explorer.Chain.InternalTransaction.{CallType, Type}
  alias Explorer.Counters.{AddressesCounter, AddressesWithBalanceCounter}
  alias Explorer.Market.MarketHistoryCache
  alias Explorer.{PagingOptions, Repo}
  alias Explorer.SmartContract.Reader

  alias Dataloader.Ecto, as: DataloaderEcto

  @default_paging_options %PagingOptions{page_size: 50}

  @max_incoming_transactions_count 10_000

  @revert_msg_prefix_1 "Revert: "
  @revert_msg_prefix_2 "revert: "
  @revert_msg_prefix_3 "reverted "
  @revert_msg_prefix_4 "Reverted "
  # keccak256("Error(string)")
  @revert_error_method_id "08c379a0"

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
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    if direction == nil do
      query_to_address_hash_wrapped =
        InternalTransaction
        |> InternalTransaction.where_address_fields_match(hash, :to_address_hash)
        |> common_where_limit_order(paging_options)
        |> wrapped_union_subquery()

      query_from_address_hash_wrapped =
        InternalTransaction
        |> InternalTransaction.where_address_fields_match(hash, :from_address_hash)
        |> common_where_limit_order(paging_options)
        |> wrapped_union_subquery()

      query_created_contract_address_hash_wrapped =
        InternalTransaction
        |> InternalTransaction.where_address_fields_match(hash, :created_contract_address_hash)
        |> common_where_limit_order(paging_options)
        |> wrapped_union_subquery()

      full_query =
        query_to_address_hash_wrapped
        |> union(^query_from_address_hash_wrapped)
        |> union(^query_created_contract_address_hash_wrapped)

      full_wrapped_query =
        from(
          q in subquery(full_query),
          select: q
        )

      full_wrapped_query
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
    |> page_internal_transaction(paging_options)
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
  @spec address_to_mined_transactions_with_rewards(Hash.Address.t(), [paging_options | necessity_by_association_option]) ::
          [
            Transaction.t()
          ]
  def address_to_mined_transactions_with_rewards(address_hash, options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    if Application.get_env(:block_scout_web, BlockScoutWeb.Chain)[:has_emission_funds] do
      cond do
        Keyword.get(options, :direction) == :from ->
          address_to_mined_transactions_without_rewards(address_hash, options)

        address_has_rewards?(address_hash) ->
          %{payout_key: block_miner_payout_address} = Reward.get_validator_payout_key_by_mining(address_hash)

          if block_miner_payout_address && address_hash == block_miner_payout_address do
            transactions_with_rewards_results(address_hash, options, paging_options)
          else
            address_to_mined_transactions_without_rewards(address_hash, options)
          end

        true ->
          address_to_mined_transactions_without_rewards(address_hash, options)
      end
    else
      address_to_mined_transactions_without_rewards(address_hash, options)
    end
  end

  defp transactions_with_rewards_results(address_hash, options, paging_options) do
    blocks_range = address_to_transactions_tasks_range_of_blocks(address_hash, options)

    rewards_task =
      Task.async(fn -> Reward.fetch_emission_rewards_tuples(address_hash, paging_options, blocks_range) end)

    [rewards_task | address_to_mined_transactions_tasks(address_hash, options)]
    |> wait_for_address_transactions()
    |> Enum.sort_by(fn item ->
      case item do
        {%Reward{} = emission_reward, _} ->
          {-emission_reward.block.number, 1}

        item ->
          {-item.block_number, -item.index}
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
    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions()
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

    options
    |> address_to_transactions_tasks_query()
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

    {block_number, transaction_index, log_index} = paging_options.key || {BlockNumber.get_max(), 0, 0}

    base_query =
      from(log in Log,
        inner_join: transaction in Transaction,
        on: transaction.hash == log.transaction_hash,
        order_by: [desc: log.block_number, desc: log.index],
        where: transaction.block_number < ^block_number,
        or_where: transaction.block_number == ^block_number and transaction.index > ^transaction_index,
        or_where:
          transaction.block_number == ^block_number and transaction.index == ^transaction_index and
            log.index > ^log_index,
        where: log.address_hash == ^address_hash,
        limit: ^paging_options.page_size,
        select: log
      )

    wrapped_query =
      from(
        log in subquery(base_query),
        inner_join: transaction in Transaction,
        preload: [:transaction, transaction: [to_address: :smart_contract]],
        where:
          log.block_hash == transaction.block_hash and
            log.block_number == transaction.block_number and
            log.transaction_hash == transaction.hash,
        select: log
      )

    wrapped_query
    |> filter_topic(options)
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
    |> fetch_transactions()
    |> join(:inner, [transaction], block in assoc(transaction, :block))
    |> where([_, block], block.hash == ^block_hash)
    |> join_associations(necessity_by_association)
    |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
    |> Repo.all()
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
    paging_options = %PagingOptions{page_size: @max_incoming_transactions_count}

    base_query =
      paging_options
      |> fetch_transactions()

    to_address_query =
      base_query
      |> where([t], t.to_address_hash == ^address_hash)

    Repo.aggregate(to_address_query, :count, :hash, timeout: :infinity)
  end

  @spec max_incoming_transactions_count() :: non_neg_integer()
  def max_incoming_transactions_count, do: @max_incoming_transactions_count

  @doc """
  How many blocks have confirmed `block` based on the current `max_block_number`

  A consensus block's number of confirmations is the difference between its number and the current block height.

      iex> block = insert(:block, number: 1)
      iex> Explorer.Chain.confirmations(block, block_height: 2)
      {:ok, 1}

  The newest block at the block height has no confirmations.

      iex> block = insert(:block, number: 1)
      iex> Explorer.Chain.confirmations(block, block_height: 1)
      {:ok, 0}

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
      {:ok, 0}
  """
  @spec confirmations(Block.t(), [{:block_height, block_height()}]) ::
          {:ok, non_neg_integer()} | {:error, :non_consensus}

  def confirmations(%Block{consensus: true, number: number}, named_arguments) when is_list(named_arguments) do
    max_consensus_block_number = Keyword.fetch!(named_arguments, :block_height)

    {:ok, max(max_consensus_block_number - number, 0)}
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

    if variant == EthereumJSONRPC.Ganache do
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

    query
    |> join_associations(necessity_by_association)
    |> with_decompiled_code_flag(hash, query_decompiled_code_flag)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      address -> {:ok, address}
    end
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
        select: token.contract_address_hash
      )

    query
    |> Repo.all()
    |> case do
      [] -> {:error, :not_found}
      hashes -> {:ok, List.first(hashes)}
    end
  end

  @spec search_token(String.t()) :: [Token.t()]
  def search_token(word) do
    term = String.replace(word, ~r/\W/u, "") <> ":*"

    query =
      from(token in Token,
        where: fragment("to_tsvector('english', symbol || ' ' || name ) @@ to_tsquery(?)", ^term),
        limit: 5,
        select: %{contract_address_hash: token.contract_address_hash, symbol: token.symbol, name: token.name}
      )

    Repo.all(query)
  end

  @spec search_contract(String.t()) :: [SmartContract.t()]
  def search_contract(word) do
    term = String.replace(word, ~r/\W/u, "") <> ":*"

    query =
      from(smart_contract in SmartContract,
        where: fragment("to_tsvector('english', name ) @@ to_tsquery(?)", ^term),
        limit: 5,
        select: %{contract_address_hash: smart_contract.address_hash, symbol: smart_contract.name}
      )

    Repo.all(query)
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
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query =
      from(
        address in Address,
        where: address.hash == ^hash and not is_nil(address.contract_code)
      )

    query
    |> join_associations(necessity_by_association)
    |> with_decompiled_code_flag(hash, query_decompiled_code_flag)
    |> Repo.one()
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
  end

  @spec fetch_count_consensus_block() :: non_neg_integer
  def fetch_count_consensus_block do
    query =
      from(block in Block,
        select: count(block.hash),
        where: block.consensus == true
      )

    Repo.one!(query)
  end

  @spec fetch_sum_coin_total_supply_minus_burnt() :: non_neg_integer
  def fetch_sum_coin_total_supply_minus_burnt do
    {:ok, burn_address_hash} = string_to_address_hash("0x0000000000000000000000000000000000000000")

    query =
      from(
        a0 in Address,
        select: fragment("SUM(a0.fetched_coin_balance)"),
        where: a0.hash != ^burn_address_hash,
        where: a0.fetched_coin_balance > ^0
      )

    Repo.one!(query) || 0
  end

  @spec fetch_sum_coin_total_supply() :: non_neg_integer
  def fetch_sum_coin_total_supply do
    query =
      from(
        a0 in Address,
        select: fragment("SUM(a0.fetched_coin_balance)"),
        where: a0.fetched_coin_balance > ^0
      )

    Repo.one!(query) || 0
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
  @spec list_top_tokens :: [{Token.t(), non_neg_integer()}]
  def list_top_tokens(options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    fetch_top_tokens(paging_options, necessity_by_association)
  end

  defp fetch_top_tokens(paging_options, necessity_by_association) do
    base_query =
      from(t in Token,
        where: t.total_supply > ^0,
        order_by: [desc: t.holder_count]
      )

    query_with_tx_count =
      from(t in subquery(base_query),
        left_join: t_t in TokenTransfer,
        where: t.contract_address_hash == t_t.token_contract_address_hash,
        where: t.total_supply > ^0,
        group_by: [t.contract_address_hash, t.decimals, t.name, t.symbol, t.total_supply, t.type, t.holder_count],
        order_by: [desc: t.holder_count],
        select_merge: %{
          contract_address_hash: t.contract_address_hash,
          decimals: t.decimals,
          name: t.name,
          symbol: t.symbol,
          total_supply: t.total_supply,
          type: t.type,
          holder_count: t.holder_count,
          txs_count: count(t_t.transaction_hash)
        }
      )

    query_with_tx_count_and_preload =
      from(t in Token,
        inner_join: t2 in subquery(query_with_tx_count),
        where: t.contract_address_hash == t2.contract_address_hash,
        preload: [:contract_address],
        # select: [t2, t]
        select: %{
          contract_address: t.contract_address,
          contract_address_hash: t.contract_address_hash,
          decimals: t.decimals,
          name: t.name,
          symbol: t.symbol,
          total_supply: t.total_supply,
          type: t.type,
          holder_count: t.holder_count,
          # txs_count: t2.txs_count
        }
        # select: %{t | txs_count: t2.txs_count}
      )

    query_with_tx_count_and_preload
    |> page_tokens(paging_options)
    |> join_associations(necessity_by_association)
    |> limit(^paging_options.page_size)
    |> Repo.all()
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
        select: b.number
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

    Repo.one!(query) || 0
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

  """
  @spec missing_block_number_ranges(Range.t()) :: [Range.t()]
  def missing_block_number_ranges(range)

  def missing_block_number_ranges(range_start..range_end) do
    range_min = min(range_start, range_end)
    range_max = max(range_start, range_end)

    missing_prefix_query =
      from(block in Block,
        select: %{min: type(^range_min, block.number), max: min(block.number) - 1},
        where: block.consensus == true,
        having: ^range_min < min(block.number) and min(block.number) < ^range_max
      )

    missing_suffix_query =
      from(block in Block,
        select: %{min: max(block.number) + 1, max: type(^range_max, block.number)},
        where: block.consensus == true,
        having: ^range_min < max(block.number) and max(block.number) < ^range_max
      )

    missing_infix_query =
      from(block in Block,
        select: %{min: type(^range_min, block.number), max: type(^range_max, block.number)},
        where: block.consensus == true,
        having:
          (is_nil(min(block.number)) and is_nil(max(block.number))) or
            (^range_max < min(block.number) or max(block.number) < ^range_min)
      )

    # Gaps and Islands is the term-of-art for finding the runs of missing (gaps) and existing (islands) data.  If you
    # Google for `sql missing ranges` you won't find much, but `sql gaps and islands` will get a lot of hits.

    land_query =
      from(block in Block,
        where: block.consensus == true and ^range_min <= block.number and block.number <= ^range_max,
        windows: [w: [order_by: block.number]],
        select: %{last_number: block.number |> lag() |> over(:w), next_number: block.number}
      )

    gap_query =
      from(
        coastline in subquery(land_query),
        where: coastline.last_number != coastline.next_number - 1,
        select: %{min: coastline.last_number + 1, max: coastline.next_number - 1}
      )

    missing_query =
      missing_prefix_query
      |> union_all(^missing_infix_query)
      |> union_all(^gap_query)
      |> union_all(^missing_suffix_query)

    {first, last, direction} =
      if range_start <= range_end do
        {:min, :max, :asc}
      else
        {:max, :min, :desc}
      end

    ordered_missing_query =
      from(missing_range in subquery(missing_query),
        select: %Range{first: field(missing_range, ^first), last: field(missing_range, ^last)},
        order_by: [{^direction, field(missing_range, ^first)}]
      )

    Repo.all(ordered_missing_query, timeout: :infinity)
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
  """
  @spec transaction_estimated_count() :: non_neg_integer()
  def transaction_estimated_count do
    cached_value = TransactionCount.get_count()

    if is_nil(cached_value) do
      %Postgrex.Result{rows: [[rows]]} =
        SQL.query!(Repo, "SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname='transactions'")

      rows
    else
      cached_value
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

    data =
      case EthereumJSONRPC.json_rpc(req, json_rpc_named_arguments) do
        {:error, %{data: data}} ->
          data

        _ ->
          ""
      end

    formatted_revert_reason = format_revert_reason_message(data)

    if byte_size(formatted_revert_reason) > 0 do
      transaction
      |> Changeset.change(%{revert_reason: formatted_revert_reason})
      |> Repo.update()
    end

    formatted_revert_reason
  end

  defp format_revert_reason_message(revert_reason) do
    case revert_reason do
      @revert_msg_prefix_1 <> rest ->
        rest

      @revert_msg_prefix_2 <> rest ->
        rest

      @revert_msg_prefix_3 <> rest ->
        extract_revert_reason_message_wrapper(rest)

      @revert_msg_prefix_4 <> rest ->
        extract_revert_reason_message_wrapper(rest)

      revert_reason_full ->
        revert_reason_full
    end
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
        where: tx.created_contract_address_hash == ^address_hash,
        select: tx.input
      )

    tx_input =
      creation_tx_query
      |> Repo.one()

    if tx_input do
      Data.to_string(tx_input)
    else
      creation_int_tx_query =
        from(
          itx in InternalTransaction,
          join: t in assoc(itx, :transaction),
          where: itx.created_contract_address_hash == ^address_hash,
          where: t.status == ^1,
          select: itx.init
        )

      itx_init_code =
        creation_int_tx_query
        |> Repo.one()

      if itx_init_code do
        Data.to_string(itx_init_code)
      else
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

    transaction = Repo.one(query)

    cond do
      is_nil(transaction) ->
        ""

      transaction.contracts_creation_internal_transaction && transaction.contracts_creation_internal_transaction.input ->
        Data.to_string(transaction.contracts_creation_internal_transaction.input)

      transaction.contracts_creation_internal_transaction && transaction.contracts_creation_internal_transaction.init ->
        Data.to_string(transaction.contracts_creation_internal_transaction.init)

      transaction.contracts_creation_transaction && transaction.contracts_creation_transaction.input ->
        Data.to_string(transaction.contracts_creation_transaction.input)

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
  def create_smart_contract(attrs \\ %{}, external_libraries \\ []) do
    new_contract = %SmartContract{}

    smart_contract_changeset =
      new_contract
      |> SmartContract.changeset(attrs)
      |> Changeset.put_change(:external_libraries, external_libraries)

    address_hash = Changeset.get_field(smart_contract_changeset, :address_hash)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    insert_result =
      Multi.new()
      |> Multi.run(:set_address_verified, fn repo, _ -> set_address_verified(repo, address_hash) end)
      |> Multi.run(:clear_primary_address_names, fn repo, _ -> clear_primary_address_names(repo, address_hash) end)
      |> Multi.run(:insert_address_name, fn repo, _ ->
        name = Changeset.get_field(smart_contract_changeset, :name)
        create_address_name(repo, name, address_hash)
      end)
      |> Multi.insert(:smart_contract, smart_contract_changeset)
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
        address_with_smart_contract = Repo.preload(address, [:smart_contract, :decompiled_smart_contracts])

        if address_with_smart_contract.smart_contract do
          formatted_code =
            SmartContract.add_submitted_comment(
              address_with_smart_contract.smart_contract.contract_source_code,
              address_with_smart_contract.smart_contract.inserted_at
            )

          %{
            address_with_smart_contract
            | smart_contract: %{address_with_smart_contract.smart_contract | contract_source_code: formatted_code}
          }
        else
          address_with_smart_contract
        end
    end
  end

  @spec address_hash_to_smart_contract(Hash.Address.t()) :: SmartContract.t() | nil
  def address_hash_to_smart_contract(address_hash) do
    query =
      from(
        smart_contract in SmartContract,
        where: smart_contract.address_hash == ^address_hash
      )

    Repo.one(query)
  end

  defp fetch_transactions(paging_options \\ nil) do
    Transaction
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
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

  defp page_tokens(query, %PagingOptions{key: {contract_address_hash}}) do
    from(token in query,
      where: token.contract_address_hash > ^contract_address_hash
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

  defp page_internal_transaction(query, %PagingOptions{key: nil}), do: query

  defp page_internal_transaction(query, %PagingOptions{key: {block_number, transaction_index, index}}) do
    where(
      query,
      [internal_transaction],
      internal_transaction.block_number < ^block_number or
        (internal_transaction.block_number == ^block_number and
           internal_transaction.transaction_index < ^transaction_index) or
        (internal_transaction.block_number == ^block_number and
           internal_transaction.transaction_index == ^transaction_index and internal_transaction.index < ^index)
    )
  end

  defp page_internal_transaction(query, %PagingOptions{key: {index}}) do
    where(query, [internal_transaction], internal_transaction.index > ^index)
  end

  defp page_logs(query, %PagingOptions{key: nil}), do: query

  defp page_logs(query, %PagingOptions{key: {index}}) do
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
  @spec total_supply :: non_neg_integer() | nil
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
        where: token.type == ^"ERC-721",
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
  def stream_cataloged_token_contract_address_hashes(initial, reducer, hours_ago_updated \\ 48)
      when is_function(reducer, 2) do
    hours_ago_updated
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
        join: t in assoc(l, :transaction),
        left_join: tf in TokenTransfer,
        on: tf.transaction_hash == l.transaction_hash and tf.log_index == l.index,
        where: l.first_topic == unquote(TokenTransfer.constant()),
        where: is_nil(tf.transaction_hash) and is_nil(tf.log_index),
        where: not is_nil(t.block_hash),
        select: t.block_number,
        distinct: t.block_number
      )

    Repo.stream_reduce(query, [], &[&1 | &2])
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
        token in Token,
        where: token.contract_address_hash == ^hash
      )

    query
    |> join_associations(necessity_by_association)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      %Token{} = token ->
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
        with {:error, %Changeset{errors: [{^stale_error_field, {^stale_error_message, []}}]}} <-
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

  @spec address_to_coin_balances(Hash.Address.t(), [paging_options]) :: []
  def address_to_coin_balances(address_hash, options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    balances_raw =
      address_hash
      |> CoinBalance.fetch_coin_balances(paging_options)
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

  # https://github.com/poanetwork/blockscout/issues/2658
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
  def fetch_token_holders_from_token_hash(contract_address_hash, options) do
    contract_address_hash
    |> CurrentTokenBalance.token_holders_ordered_by_value(options)
    |> Repo.all()
  end

  @spec count_token_holders_from_token_hash(Hash.Address.t()) :: non_neg_integer()
  def count_token_holders_from_token_hash(contract_address_hash) do
    query = from(ctb in CurrentTokenBalance.token_holders_query(contract_address_hash), select: fragment("COUNT(*)"))

    Repo.one!(query)
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
          :erc20 | :erc721 | :token_transfer | nil
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

      {"0xf907fc5b" <> _params, ^zero_wei} ->
        :erc20

      # check for ERC 20 or for old ERC 721 token versions
      {unquote(TokenTransfer.transfer_function_signature()) <> params, ^zero_wei} ->
        types = [:address, {:uint, 256}]

        [address, value] = decode_params(params, types)

        decimal_value = Decimal.new(value)

        find_erc721_or_erc20_token_transfer(transaction.token_transfers, {address, decimal_value})

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

  defp find_erc721_or_erc20_token_transfer(token_transfers, {address, decimal_value}) do
    token_transfer =
      Enum.find(token_transfers, fn token_transfer ->
        token_transfer.to_address_hash.bytes == address && token_transfer.amount == decimal_value
      end)

    if token_transfer do
      case token_transfer.token do
        %Token{type: "ERC-20"} -> :erc20
        %Token{type: "ERC-721"} -> :erc721
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
  @spec staking_pools(filter :: :validator | :active | :inactive, options :: PagingOptions.t()) :: [map()]
  def staking_pools(filter, %PagingOptions{page_size: page_size, page_number: page_number} \\ @default_paging_options) do
    off = page_size * (page_number - 1)

    StakingPool
    |> staking_pool_filter(filter)
    |> limit(^page_size)
    |> offset(^off)
    |> Repo.all()
  end

  @doc "Get count of staking pools from the DB"
  @spec staking_pools_count(filter :: :validator | :active | :inactive) :: integer
  def staking_pools_count(filter) do
    StakingPool
    |> staking_pool_filter(filter)
    |> Repo.aggregate(:count, :staking_address_hash)
  end

  defp staking_pool_filter(query, :validator) do
    where(
      query,
      [pool],
      pool.is_active == true and
        pool.is_deleted == false and
        pool.is_validator == true
    )
  end

  defp staking_pool_filter(query, :active) do
    where(
      query,
      [pool],
      pool.is_active == true and
        pool.is_deleted == false
    )
  end

  defp staking_pool_filter(query, :inactive) do
    where(
      query,
      [pool],
      pool.is_active == false and
        pool.is_deleted == false
    )
  end

  defp staking_pool_filter(query, _), do: query

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

  def extract_db_name(db_url) do
    if db_url == nil do
      ""
    else
      db_url
      |> String.split("/")
      |> Enum.take(-1)
      |> Enum.at(0)
    end
  end

  def extract_db_host(db_url) do
    if db_url == nil do
      ""
    else
      db_url
      |> String.split("@")
      |> Enum.take(-1)
      |> Enum.at(0)
      |> String.split(":")
      |> Enum.at(0)
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

  def is_proxy_contract?(abi) when not is_nil(abi) do
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        Map.get(method, "name") == "implementation"
      end)

    if implementation_method_abi, do: true, else: false
  end

  def is_proxy_contract?(abi) when is_nil(abi) do
    false
  end

  def get_implementation_address_hash(proxy_address_hash, abi)
      when not is_nil(proxy_address_hash) and not is_nil(abi) do
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        Map.get(method, "name") == "implementation"
      end)

    implementation_method_abi_state_mutability = Map.get(implementation_method_abi, "stateMutability")
    is_eip1967 = if implementation_method_abi_state_mutability == "nonpayable", do: true, else: false

    if is_eip1967 do
      json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

      # https://eips.ethereum.org/EIPS/eip-1967
      eip_1967_implementation_storage_pointer = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

      {:ok, implementation_address} =
        Contract.eth_get_storage_at_request(
          proxy_address_hash,
          eip_1967_implementation_storage_pointer,
          nil,
          json_rpc_named_arguments
        )

      if String.length(implementation_address) > 42 do
        "0x" <> String.slice(implementation_address, -40, 40)
      else
        implementation_address
      end
    else
      implementation_address =
        case Reader.query_contract(proxy_address_hash, abi, %{
               "implementation" => []
             }) do
          %{"implementation" => {:ok, [result]}} -> result
          _ -> nil
        end

      if implementation_address do
        "0x" <> Base.encode16(implementation_address, case: :lower)
      else
        nil
      end
    end
  end

  def get_implementation_address_hash(proxy_address_hash, abi) when is_nil(proxy_address_hash) or is_nil(abi) do
    nil
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
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        Map.get(method, "name") == "implementation"
      end)

    if implementation_method_abi do
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
        |> Enum.find(fn {trace, _} ->
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
    |> Repo.one()
  end
end
