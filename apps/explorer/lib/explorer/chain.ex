defmodule Explorer.Chain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query,
    only: [
      dynamic: 1,
      dynamic: 2,
      from: 2,
      join: 4,
      join: 5,
      limit: 2,
      lock: 2,
      offset: 2,
      order_by: 2,
      order_by: 3,
      preload: 2,
      select: 2,
      select: 3,
      subquery: 1,
      union: 2,
      update: 2,
      where: 2,
      where: 3
    ]

  import EthereumJSONRPC, only: [integer_to_quantity: 1, fetch_block_internal_transactions: 2]

  require Logger

  alias ABI.TypeDecoder
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
    CurrencyHelpers,
    Data,
    DecompiledSmartContract,
    Hash,
    Import,
    InternalTransaction,
    Log,
    PendingBlockOperation,
    SmartContract,
    SmartContractAdditionalSource,
    Token,
    Token.Instance,
    TokenTransfer,
    Transaction,
    Wei
  }

  alias Explorer.Chain.Block.{EmissionReward, Reward}

  alias Explorer.Chain.Cache.{
    Accounts,
    BlockNumber,
    Blocks,
    ContractsCounter,
    NewContractsCounter,
    NewVerifiedContractsCounter,
    Transactions,
    Uncles,
    VerifiedContractsCounter
  }

  alias Explorer.Chain.Import.Runner
  alias Explorer.Chain.InternalTransaction.{CallType, Type}

  alias Explorer.Counters.{
    AddressesCounter,
    AddressesWithBalanceCounter
  }

  alias Explorer.Market.MarketHistoryCache
  alias Explorer.{PagingOptions, Repo}
  alias Explorer.SmartContract.{Helper, Reader}

  alias Dataloader.Ecto, as: DataloaderEcto

  @default_paging_options %PagingOptions{page_size: 50}

  @token_transfers_per_transaction_preview 10
  @token_transfers_neccessity_by_association %{
    [from_address: :smart_contract] => :optional,
    [to_address: :smart_contract] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    token: :required
  }

  @method_name_to_id_map %{
    "approve" => "095ea7b3",
    "transfer" => "a9059cbb",
    "multicall" => "5ae401dc",
    "mint" => "40c10f19",
    "commit" => "f14fcbc8"
  }

  @max_incoming_transactions_count 10_000

  @revert_msg_prefix_1 "Revert: "
  @revert_msg_prefix_2 "revert: "
  @revert_msg_prefix_3 "reverted "
  @revert_msg_prefix_4 "Reverted "
  # Geth-like node
  @revert_msg_prefix_5 "execution reverted: "
  # keccak256("Error(string)")
  @revert_error_method_id "08c379a0"

  @burn_address_hash_str "0x0000000000000000000000000000000000000000"

  # seconds
  @check_bytecode_interval 86_400

  @limit_showing_transactions 10_000
  @default_page_size 50

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

    if is_nil(cached_value) || cached_value == 0 do
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
    Repo.aggregate(Address, :count, timeout: :infinity)
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
      full_query =
        InternalTransaction
        |> InternalTransaction.where_nonpending_block()
        |> InternalTransaction.where_address_fields_match(hash, nil)
        |> InternalTransaction.where_block_number_in_period(from_block, to_block)
        |> common_where_limit_order(paging_options)

      full_query
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

  @doc """
  address_hash_to_token_transfers_including_contract/2 function returns token transfers on address (to/from/contract).
  It is used by CSV export of token transfers button.
  """
  @spec address_hash_to_token_transfers_including_contract(Hash.Address.t(), Keyword.t()) :: [TokenTransfer.t()]
  def address_hash_to_token_transfers_including_contract(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    from_block = Keyword.get(options, :from_block)
    to_block = Keyword.get(options, :to_block)

    query =
      from_block
      |> query_address_hash_to_token_transfers_including_contract(to_block, address_hash)
      |> order_by([token_transfer], asc: token_transfer.block_number, asc: token_transfer.log_index)

    query
    |> handle_token_transfer_paging_options(paging_options)
    |> preload(transaction: :block)
    |> preload(:token)
    |> Repo.all()
  end

  defp query_address_hash_to_token_transfers_including_contract(nil, to_block, address_hash)
       when not is_nil(to_block) do
    from(
      token_transfer in TokenTransfer,
      where:
        (token_transfer.to_address_hash == ^address_hash or
           token_transfer.from_address_hash == ^address_hash or
           token_transfer.token_contract_address_hash == ^address_hash) and
          token_transfer.block_number <= ^to_block
    )
  end

  defp query_address_hash_to_token_transfers_including_contract(from_block, nil, address_hash)
       when not is_nil(from_block) do
    from(
      token_transfer in TokenTransfer,
      where:
        (token_transfer.to_address_hash == ^address_hash or
           token_transfer.from_address_hash == ^address_hash or
           token_transfer.token_contract_address_hash == ^address_hash) and
          token_transfer.block_number >= ^from_block
    )
  end

  defp query_address_hash_to_token_transfers_including_contract(from_block, to_block, address_hash)
       when not is_nil(from_block) and not is_nil(to_block) do
    from(
      token_transfer in TokenTransfer,
      where:
        (token_transfer.to_address_hash == ^address_hash or
           token_transfer.from_address_hash == ^address_hash or
           token_transfer.token_contract_address_hash == ^address_hash) and
          (token_transfer.block_number >= ^from_block and token_transfer.block_number <= ^to_block)
    )
  end

  defp query_address_hash_to_token_transfers_including_contract(_, _, address_hash) do
    from(
      token_transfer in TokenTransfer,
      where:
        token_transfer.to_address_hash == ^address_hash or
          token_transfer.from_address_hash == ^address_hash or
          token_transfer.token_contract_address_hash == ^address_hash
    )
  end

  @spec address_to_logs(Hash.Address.t(), Keyword.t()) :: [Log.t()]
  def address_to_logs(address_hash, options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options) || %PagingOptions{page_size: 50}

    from_block = from_block(options)
    to_block = to_block(options)

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
    base_query
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
    block_hash =
      Block
      |> where([block], block.number == ^block_number and block.consensus)
      |> select([block], block.hash)
      |> Repo.one!()

    case Repo.one!(
           from(reward in Reward,
             where: reward.block_hash == ^block_hash,
             select: %Wei{
               value: coalesce(sum(reward.reward), 0)
             }
           )
         ) do
      %Wei{
        value: %Decimal{coef: 0}
      } ->
        Repo.one!(
          from(block in Block,
            left_join: transaction in assoc(block, :transactions),
            inner_join: emission_reward in EmissionReward,
            on: fragment("? <@ ?", block.number, emission_reward.block_range),
            where: block.number == ^block_number and block.consensus,
            group_by: [emission_reward.reward, block.hash],
            select: %Wei{
              value: coalesce(sum(transaction.gas_used * transaction.gas_price), 0) + emission_reward.reward
            }
          )
        )

      other_value ->
        other_value
    end
  end

  def txn_fees(transactions) do
    Enum.reduce(transactions, Decimal.new(0), fn %{gas_used: gas_used, gas_price: gas_price}, acc ->
      gas_used
      |> Decimal.new()
      |> Decimal.mult(gas_price_to_decimal(gas_price))
      |> Decimal.add(acc)
    end)
  end

  defp gas_price_to_decimal(%Wei{} = wei), do: wei.value
  defp gas_price_to_decimal(gas_price), do: Decimal.new(gas_price)

  def burned_fees(transactions, base_fee_per_gas) do
    burned_fee_counter =
      transactions
      |> Enum.reduce(Decimal.new(0), fn %{gas_used: gas_used}, acc ->
        gas_used
        |> Decimal.new()
        |> Decimal.add(acc)
      end)

    base_fee_per_gas && Wei.mult(base_fee_per_gas_to_wei(base_fee_per_gas), burned_fee_counter)
  end

  defp base_fee_per_gas_to_wei(%Wei{} = wei), do: wei
  defp base_fee_per_gas_to_wei(base_fee_per_gas), do: %Wei{value: Decimal.new(base_fee_per_gas)}

  @uncle_reward_coef 1 / 32
  def block_reward_by_parts(block, transactions) do
    %{hash: block_hash, number: block_number} = block
    base_fee_per_gas = Map.get(block, :base_fee_per_gas)

    txn_fees = txn_fees(transactions)

    static_reward =
      Repo.one(
        from(
          er in EmissionReward,
          where: fragment("int8range(?, ?) <@ ?", ^block_number, ^(block_number + 1), er.block_range),
          select: er.reward
        )
      ) || %Wei{value: Decimal.new(0)}

    has_uncles? = is_list(block.uncles) and not Enum.empty?(block.uncles)

    burned_fees = burned_fees(transactions, base_fee_per_gas)
    uncle_reward = (has_uncles? && Wei.mult(static_reward, Decimal.from_float(@uncle_reward_coef))) || nil

    %{
      block_number: block_number,
      block_hash: block_hash,
      miner_hash: block.miner_hash,
      static_reward: static_reward,
      txn_fees: %Wei{value: txn_fees},
      burned_fees: burned_fees || %Wei{value: Decimal.new(0)},
      uncle_reward: uncle_reward || %Wei{value: Decimal.new(0)}
    }
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
  @spec block_to_transactions(Hash.Full.t(), [paging_options | necessity_by_association_option], true | false) :: [
          Transaction.t()
        ]
  def block_to_transactions(block_hash, options \\ [], old_ui? \\ true) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions_in_ascending_order_by_index()
    |> join(:inner, [transaction], block in assoc(transaction, :block))
    |> where([_, block], block.hash == ^block_hash)
    |> join_associations(necessity_by_association)
    |> (&if(old_ui?, do: preload(&1, [{:token_transfers, [:token, :from_address, :to_address]}]), else: &1)).()
    |> Repo.all()
    |> (&if(old_ui?,
          do: &1,
          else: Enum.map(&1, fn tx -> preload_token_transfers(tx, @token_transfers_neccessity_by_association) end)
        )).()
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

    case block.base_fee_per_gas do
      %Wei{value: base_fee_per_gas} ->
        query =
          from(
            tx in Transaction,
            where: tx.block_hash == ^block_hash,
            select:
              sum(
                fragment(
                  "CASE
                    WHEN COALESCE(?,?) = 0 THEN 0
                    WHEN COALESCE(?,?) - ? < COALESCE(?,?) THEN (COALESCE(?,?) - ?) * ?
                    ELSE COALESCE(?,?) * ? END",
                  tx.max_fee_per_gas,
                  tx.gas_price,
                  tx.max_fee_per_gas,
                  tx.gas_price,
                  ^base_fee_per_gas,
                  tx.max_priority_fee_per_gas,
                  tx.gas_price,
                  tx.max_fee_per_gas,
                  tx.gas_price,
                  ^base_fee_per_gas,
                  tx.gas_used,
                  tx.max_priority_fee_per_gas,
                  tx.gas_price,
                  tx.gas_used
                )
              )
          )

        result = Repo.one(query)
        if result, do: result, else: 0

      _ ->
        0
    end
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

  @spec address_hash_to_transaction_count(Hash.Address.t()) :: non_neg_integer()
  def address_hash_to_transaction_count(address_hash) do
    query =
      from(
        transaction in Transaction,
        where: transaction.to_address_hash == ^address_hash or transaction.from_address_hash == ^address_hash
      )

    Repo.aggregate(query, :count, :hash, timeout: :infinity)
  end

  @spec address_to_incoming_transaction_gas_usage(Hash.Address.t()) :: Decimal.t() | nil
  def address_to_incoming_transaction_gas_usage(address_hash) do
    to_address_query =
      from(
        transaction in Transaction,
        where: transaction.to_address_hash == ^address_hash
      )

    Repo.aggregate(to_address_query, :sum, :gas_used, timeout: :infinity)
  end

  @spec address_to_outcoming_transaction_gas_usage(Hash.Address.t()) :: Decimal.t() | nil
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
  @spec confirmations(Block.t() | nil, [{:block_height, block_height()}]) ::
          {:ok, non_neg_integer()} | {:error, :non_consensus | :pending}

  def confirmations(%Block{consensus: true, number: number}, named_arguments) when is_list(named_arguments) do
    max_consensus_block_number = Keyword.fetch!(named_arguments, :block_height)

    {:ok, max(1 + max_consensus_block_number - number, 1)}
  end

  def confirmations(%Block{consensus: false}, _), do: {:error, :non_consensus}

  def confirmations(nil, _), do: {:error, :pending}

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
  @spec fee(Transaction.t(), :ether | :gwei | :wei) :: {:maximum, Decimal.t()} | {:actual, Decimal.t()}
  def fee(%Transaction{gas: gas, gas_price: gas_price, gas_used: nil}, unit) do
    fee =
      gas_price
      |> Wei.to(unit)
      |> Decimal.mult(gas)

    {:maximum, fee}
  end

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
  @spec finished_internal_transactions_indexing?() :: boolean()
  def finished_internal_transactions_indexing? do
    internal_transactions_disabled? = System.get_env("INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER", "false") == "true"

    if internal_transactions_disabled? do
      true
    else
      json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      if variant == EthereumJSONRPC.Ganache || variant == EthereumJSONRPC.Arbitrum do
        true
      else
        with {:transactions_exist, true} <- {:transactions_exist, Repo.exists?(Transaction)},
             min_block_number when not is_nil(min_block_number) <- Repo.aggregate(Transaction, :min, :block_number) do
          min_block_number =
            min_block_number
            |> Decimal.max(EthereumJSONRPC.first_block_to_fetch(:trace_first_block))
            |> Decimal.to_integer()

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
  end

  @doc """
  Checks if indexing of blocks and internal transactions finished aka full indexing
  """
  @spec finished_indexing?(Decimal.t()) :: boolean()
  def finished_indexing?(indexed_ratio) do
    case Decimal.compare(indexed_ratio, 1) do
      :lt -> false
      _ -> Chain.finished_internal_transactions_indexing?()
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

  defp prepare_search_term(string) do
    case Regex.scan(~r/[a-zA-Z0-9]+/, string) do
      [_ | _] = words ->
        term_final =
          words
          |> Enum.map_join(" & ", fn [word] -> word <> ":*" end)

        {:some, term_final}

      _ ->
        :none
    end
  end

  defp search_token_query(term) do
    from(token in Token,
      where: fragment("to_tsvector(symbol || ' ' || name ) @@ to_tsquery(?)", ^term),
      select: %{
        address_hash: token.contract_address_hash,
        tx_hash: fragment("CAST(NULL AS bytea)"),
        block_hash: fragment("CAST(NULL AS bytea)"),
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
          {block_number, ""} ->
            from(block in Block,
              where: block.number == ^block_number,
              select: %{
                address_hash: fragment("CAST(NULL AS bytea)"),
                tx_hash: fragment("CAST(NULL AS bytea)"),
                block_hash: block.hash,
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

  def joint_search(paging_options, offset, raw_string) do
    string = String.trim(raw_string)

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

          result_checksummed_address_hash
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
        smart_contract_additional_sources: :optional
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
            check_bytecode_matching(address_result)
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

  defp check_bytecode_matching(address) do
    now = DateTime.utc_now()
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    if !address.smart_contract.is_changed_bytecode and
         address.smart_contract.bytecode_checked_at
         |> DateTime.add(@check_bytecode_interval, :second)
         |> DateTime.compare(now) != :gt do
      case EthereumJSONRPC.fetch_codes(
             [%{block_quantity: "latest", address: address.smart_contract.address_hash}],
             json_rpc_named_arguments
           ) do
        {:ok, %EthereumJSONRPC.FetchedCodes{params_list: fetched_codes}} ->
          bytecode_from_node = fetched_codes |> List.first() |> Map.get(:code)
          bytecode_from_db = "0x" <> (address.contract_code.bytes |> Base.encode16(case: :lower))

          if bytecode_from_node == bytecode_from_db do
            {:ok, smart_contract} =
              address.smart_contract
              |> Changeset.change(%{bytecode_checked_at: now})
              |> Repo.update()

            %{address | smart_contract: smart_contract}
          else
            {:ok, smart_contract} =
              address.smart_contract
              |> Changeset.change(%{bytecode_checked_at: now, is_changed_bytecode: true})
              |> Repo.update()

            %{address | smart_contract: smart_contract}
          end

        _ ->
          address
      end
    else
      address
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

  # preload_to_detect_tt?: we don't need to preload more than one token transfer in case the tx inside the list (we dont't show any token transfers on tx tile in new UI)
  def preload_token_transfers(
        %Transaction{hash: tx_hash, block_hash: block_hash} = transaction,
        necessity_by_association,
        preload_to_detect_tt? \\ true
      ) do
    token_transfers =
      TokenTransfer
      |> (&if(is_nil(block_hash),
            do: where(&1, [token_transfer], token_transfer.transaction_hash == ^tx_hash),
            else:
              where(
                &1,
                [token_transfer],
                token_transfer.transaction_hash == ^tx_hash and token_transfer.block_hash == ^block_hash
              )
          )).()
      |> limit(^if(preload_to_detect_tt?, do: 1, else: @token_transfers_per_transaction_preview + 1))
      |> order_by([token_transfer], asc: token_transfer.log_index)
      |> join_associations(necessity_by_association)
      |> Repo.all()

    %Transaction{transaction | token_transfers: token_transfers}
  end

  def get_token_transfers_per_transaction_preview_count, do: @token_transfers_per_transaction_preview

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
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

    min_blockchain_block_number =
      case Integer.parse(Application.get_env(:indexer, :first_block)) do
        {block_number, _} -> block_number
        _ -> 0
      end

    case {min, max} do
      {0, 0} ->
        Decimal.new(0)

      _ ->
        result = Decimal.div(max - min + 1, max - min_blockchain_block_number + 1)

        result
        |> Decimal.round(2, :down)
        |> Decimal.min(Decimal.new(1))
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

  def fetch_block_by_hash(block_hash) do
    Repo.get(Block, block_hash)
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

    query =
      if filter && filter !== "" do
        case prepare_search_term(filter) do
          {:some, filter_term} ->
            base_query_with_paging
            |> where(fragment("to_tsvector('english', symbol || ' ' || name ) @@ to_tsquery(?)", ^filter_term))

          _ ->
            base_query_with_paging
        end
      else
        base_query_with_paging
      end

    query
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
    address_hash_to_transaction_count(address.hash)
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

  @spec address_to_gas_usage_count(Address.t()) :: Decimal.t() | nil
  def address_to_gas_usage_count(address) do
    if contract?(address) do
      incoming_transaction_gas_usage = address_to_incoming_transaction_gas_usage(address.hash)

      cond do
        !incoming_transaction_gas_usage ->
          address_to_outcoming_transaction_gas_usage(address.hash)

        Decimal.compare(incoming_transaction_gas_usage, 0) == :eq ->
          address_to_outcoming_transaction_gas_usage(address.hash)

        true ->
          incoming_transaction_gas_usage
      end
    else
      address_to_outcoming_transaction_gas_usage(address.hash)
    end
  end

  @doc """
  Return the balance in usd corresponding to this token. Return nil if the usd_value of the token is not present.
  """
  def balance_in_usd(_token_balance, %{usd_value: nil}) do
    nil
  end

  def balance_in_usd(token_balance, %{usd_value: usd_value, decimals: decimals}) do
    tokens = CurrencyHelpers.divide_decimals(token_balance.value, decimals)
    Decimal.mult(tokens, usd_value)
  end

  def balance_in_usd(%{token: %{usd_value: nil}}) do
    nil
  end

  def balance_in_usd(token_balance) do
    tokens = CurrencyHelpers.divide_decimals(token_balance.value, token_balance.token.decimals)
    price = token_balance.token.usd_value
    Decimal.mult(tokens, price)
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

    Repo.one!(query) || Decimal.new(0)
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
            (
              SELECT distinct b1.number
              FROM generate_series((?)::integer, (?)::integer) AS b1(number)
              WHERE NOT EXISTS
                (SELECT 1 FROM blocks b2 WHERE b2.number=b1.number AND b2.consensus)
              ORDER BY b1.number DESC
              LIMIT 500000
            )
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

  @spec timestamp_to_block_number(DateTime.t(), :before | :after, boolean()) ::
          {:ok, Block.block_number()} | {:error, :not_found}
  def timestamp_to_block_number(given_timestamp, closest, from_api) do
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

    response =
      if from_api do
        query
        |> Repo.replica().one()
      else
        query
        |> Repo.one()
      end

    response
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
      iex> recent_collated_transactions = Explorer.Chain.recent_collated_transactions(true, paging_options: paging_options)
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
  @spec recent_collated_transactions(true | false, [paging_options | necessity_by_association_option], [String.t()], [
          :atom
        ]) :: [
          Transaction.t()
        ]
  def recent_collated_transactions(old_ui?, options \\ [], method_id_filter \\ [], type_filter \\ [])
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    fetch_recent_collated_transactions(old_ui?, paging_options, necessity_by_association, method_id_filter, type_filter)
  end

  # RAP - random access pagination
  @spec recent_collated_transactions_for_rap([paging_options | necessity_by_association_option]) :: %{
          :total_transactions_count => non_neg_integer(),
          :transactions => [Transaction.t()]
        }
  def recent_collated_transactions_for_rap(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    total_transactions_count = transactions_available_count()

    fetched_transactions =
      if is_nil(paging_options.key) or paging_options.page_number == 1 do
        paging_options.page_size
        |> Kernel.+(1)
        |> Transactions.take_enough()
        |> case do
          nil ->
            transactions = fetch_recent_collated_transactions_for_rap(paging_options, necessity_by_association)
            Transactions.update(transactions)
            transactions

          transactions ->
            transactions
        end
      else
        fetch_recent_collated_transactions_for_rap(paging_options, necessity_by_association)
      end

    %{total_transactions_count: total_transactions_count, transactions: fetched_transactions}
  end

  def default_page_size, do: @default_page_size

  def fetch_recent_collated_transactions_for_rap(paging_options, necessity_by_association) do
    fetch_transactions_for_rap()
    |> where([transaction], not is_nil(transaction.block_number) and not is_nil(transaction.index))
    |> handle_random_access_paging_options(paging_options)
    |> join_associations(necessity_by_association)
    |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
    |> Repo.all()
  end

  defp fetch_transactions_for_rap do
    Transaction
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
  end

  def transactions_available_count do
    Transaction
    |> where([transaction], not is_nil(transaction.block_number) and not is_nil(transaction.index))
    |> limit(^@limit_showing_transactions)
    |> Repo.aggregate(:count, :hash)
  end

  def fetch_recent_collated_transactions(
        old_ui?,
        paging_options,
        necessity_by_association,
        method_id_filter,
        type_filter
      ) do
    paging_options
    |> fetch_transactions()
    |> where([transaction], not is_nil(transaction.block_number) and not is_nil(transaction.index))
    |> apply_filter_by_method_id_to_transactions(method_id_filter)
    |> apply_filter_by_tx_type_to_transactions(type_filter)
    |> join_associations(necessity_by_association)
    |> (&if(old_ui?, do: preload(&1, [{:token_transfers, [:token, :from_address, :to_address]}]), else: &1)).()
    |> debug("result collated query")
    |> Repo.all()
    |> (&if(old_ui?,
          do: &1,
          else: Enum.map(&1, fn tx -> preload_token_transfers(tx, @token_transfers_neccessity_by_association) end)
        )).()
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
  @spec recent_pending_transactions([paging_options | necessity_by_association_option], true | false, [String.t()], [
          :atom
        ]) :: [Transaction.t()]
  def recent_pending_transactions(options \\ [], old_ui? \\ true, method_id_filter \\ [], type_filter \\ [])
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    Transaction
    |> page_pending_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> pending_transactions_query()
    |> apply_filter_by_method_id_to_transactions(method_id_filter)
    |> apply_filter_by_tx_type_to_transactions(type_filter)
    |> order_by([transaction], desc: transaction.inserted_at, desc: transaction.hash)
    |> join_associations(necessity_by_association)
    |> (&if(old_ui?, do: preload(&1, [{:token_transfers, [:token, :from_address, :to_address]}]), else: &1)).()
    |> debug("result pendging query")
    |> Repo.all()
    |> (&if(old_ui?,
          do: &1,
          else: Enum.map(&1, fn tx -> preload_token_transfers(tx, @token_transfers_neccessity_by_association) end)
        )).()
  end

  def pending_transactions_query(query) do
    from(transaction in query,
      where: is_nil(transaction.block_hash) and (is_nil(transaction.error) or transaction.error != "dropped/replaced")
    )
  end

  def pending_transactions_list do
    query =
      from(transaction in Transaction,
        where: is_nil(transaction.block_hash) and (is_nil(transaction.error) or transaction.error != "dropped/replaced")
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
          bytes: <<90, 174, 182, 5, 63, 62, 148, 201, 185, 160, 159, 51, 102, 148, 53,
            231, 239, 27, 234, 237>>
        }
      }

      iex> Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      {
        :ok,
        %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<90, 174, 182, 5, 63, 62, 148, 201, 185, 160, 159, 51, 102, 148, 53,
            231, 239, 27, 234, 237>>
        }
      }

      iex> Base.encode16(<<90, 174, 182, 5, 63, 62, 148, 201, 185, 160, 159, 51, 102, 148, 53, 231, 239, 27, 234, 237>>, case: :lower)
      "5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"

  `String.t` format must always have 40 hexadecimal digits after the `0x` base prefix.

      iex> Explorer.Chain.string_to_address_hash("0x0")
      :error

  """
  @spec string_to_address_hash(String.t()) :: {:ok, Hash.Address.t()} | :error
  def string_to_address_hash(string) when is_binary(string) do
    Hash.Address.cast(string)
  end

  def string_to_address_hash(_), do: :error

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

  def string_to_block_hash(_), do: :error

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

  def string_to_transaction_hash(_), do: :error

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
  @spec transaction_to_logs(Hash.Full.t(), boolean(), [paging_options | necessity_by_association_option]) :: [Log.t()]
  def transaction_to_logs(transaction_hash, from_api, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    log_with_transactions =
      from(log in Log,
        inner_join: transaction in Transaction,
        on:
          transaction.block_hash == log.block_hash and transaction.block_number == log.block_number and
            transaction.hash == log.transaction_hash
      )

    query =
      log_with_transactions
      |> where([_, transaction], transaction.hash == ^transaction_hash)
      |> page_logs(paging_options)
      |> limit(^paging_options.page_size)
      |> order_by([log], asc: log.index)
      |> join_associations(necessity_by_association)

    if from_api do
      query
      |> Repo.replica().all()
    else
      query
      |> Repo.all()
    end
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
    paging_options = options |> Keyword.get(:paging_options, @default_paging_options) |> Map.put(:asc_order, true)

    TokenTransfer
    |> join(:inner, [token_transfer], transaction in assoc(token_transfer, :transaction))
    |> where(
      [token_transfer, transaction],
      transaction.hash == ^transaction_hash and token_transfer.block_hash == transaction.block_hash and
        token_transfer.block_number == transaction.block_number
    )
    |> TokenTransfer.page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([token_transfer], asc: token_transfer.log_index)
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
        {:error, %{data: data}} ->
          data

        {:error, %{message: message}} ->
          message

        _ ->
          ""
      end

    formatted_revert_reason =
      revert_reason |> format_revert_reason_message() |> (&if(String.valid?(&1), do: &1, else: revert_reason)).()

    if byte_size(formatted_revert_reason) > 0 do
      transaction
      |> Changeset.change(%{revert_reason: formatted_revert_reason})
      |> Repo.update()
    end

    formatted_revert_reason
  end

  def format_revert_reason_message(revert_reason) do
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

    attrs =
      attrs
      |> Helper.add_contract_code_md5()

    smart_contract_changeset =
      new_contract
      |> SmartContract.changeset(attrs)
      |> Changeset.put_change(:external_libraries, external_libraries)

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

    create_address_name(Repo, Changeset.get_field(smart_contract_changeset, :name), address_hash)

    case insert_result do
      {:ok, %{smart_contract: smart_contract}} ->
        {:ok, smart_contract}

      {:error, :smart_contract, changeset, _} ->
        {:error, changeset}

      {:error, :set_address_verified, message, _} ->
        {:error, message}
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

  @doc """
  Finds metadata for verification of a contract from verified twins: contracts with the same bytecode
  which were verified previously, returns a single t:SmartContract.t/0
  """
  def get_address_verified_twin_contract(hash) when is_binary(hash) do
    case string_to_address_hash(hash) do
      {:ok, address_hash} -> get_address_verified_twin_contract(address_hash)
      _ -> %{:verified_contract => nil, :additional_sources => nil}
    end
  end

  def get_address_verified_twin_contract(%Explorer.Chain.Hash{} = address_hash) do
    with target_address <- Repo.get(Address, address_hash),
         false <- is_nil(target_address),
         %{contract_code: %Chain.Data{bytes: contract_code_bytes}} <- target_address do
      target_address_hash = target_address.hash

      contract_code_md5 = Helper.contract_code_md5(contract_code_bytes)

      verified_contract_twin_query =
        from(
          smart_contract in SmartContract,
          where: smart_contract.contract_code_md5 == ^contract_code_md5,
          where: smart_contract.address_hash != ^target_address_hash,
          select: smart_contract,
          limit: 1
        )

      verified_contract_twin =
        verified_contract_twin_query
        |> Repo.one(timeout: 10_000)

      verified_contract_twin_additional_sources = get_contract_additional_sources(verified_contract_twin)

      %{
        :verified_contract => verified_contract_twin,
        :additional_sources => verified_contract_twin_additional_sources
      }
    else
      _ ->
        %{:verified_contract => nil, :additional_sources => nil}
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

    if result, do: !result.partially_verified, else: false
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

  defp handle_paging_options(query, %PagingOptions{key: nil, page_size: nil}), do: query

  defp handle_paging_options(query, paging_options) do
    query
    |> page_transaction(paging_options)
    |> limit(^paging_options.page_size)
  end

  defp handle_verified_contracts_paging_options(query, nil), do: query

  defp handle_verified_contracts_paging_options(query, paging_options) do
    query
    |> page_verified_contracts(paging_options)
    |> limit(^paging_options.page_size)
  end

  defp handle_token_transfer_paging_options(query, nil), do: query

  defp handle_token_transfer_paging_options(query, paging_options) do
    query
    |> TokenTransfer.page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
  end

  defp handle_random_access_paging_options(query, empty_options) when empty_options in [nil, [], %{}],
    do: limit(query, ^(@default_page_size + 1))

  defp handle_random_access_paging_options(query, paging_options) do
    query
    |> (&if(paging_options |> Map.get(:page_number, 1) |> proccess_page_number() == 1,
          do: &1,
          else: page_transaction(&1, paging_options)
        )).()
    |> handle_page(paging_options)
  end

  defp handle_page(query, paging_options) do
    page_number = paging_options |> Map.get(:page_number, 1) |> proccess_page_number()
    page_size = Map.get(paging_options, :page_size, @default_page_size)

    cond do
      page_in_bounds?(page_number, page_size) && page_number == 1 ->
        query
        |> limit(^(page_size + 1))

      page_in_bounds?(page_number, page_size) ->
        query
        |> limit(^page_size)
        |> offset(^((page_number - 2) * page_size))

      true ->
        query
        |> limit(^(@default_page_size + 1))
    end
  end

  defp proccess_page_number(number) when number < 1, do: 1

  defp proccess_page_number(number), do: number

  defp page_in_bounds?(page_number, page_size),
    do: page_size <= @limit_showing_transactions && @limit_showing_transactions - page_number * page_size >= 0

  def limit_showing_transactions, do: @limit_showing_transactions

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

  defp join_association(query, association, necessity) do
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
      [ctb, t],
      ctb.value < ^value or (ctb.value == ^value and t.type < ^type) or
        (ctb.value == ^value and t.type == ^type and t.name < ^name)
    )
  end

  defp page_verified_contracts(query, %PagingOptions{key: nil}), do: query

  defp page_verified_contracts(query, %PagingOptions{key: {id}}) do
    where(query, [contract], contract.id < ^id)
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
          token_transfer.token_contract_address_hash == instance.token_contract_address_hash and
            (token_transfer.token_id == instance.token_id or
               fragment("? @> ARRAY[?::decimal]", token_transfer.token_ids, instance.token_id)),
        where:
          is_nil(instance.token_id) and (not is_nil(token_transfer.token_id) or not is_nil(token_transfer.token_ids)),
        select: %{
          contract_address_hash: token_transfer.token_contract_address_hash,
          token_id: token_transfer.token_id,
          token_ids: token_transfer.token_ids
        }
      )

    distinct_query =
      from(
        q in subquery(query),
        distinct: [q.contract_address_hash, q.token_id, q.token_ids]
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
        where: t.contract_address_hash == ^hash,
        select: t
      )

    query
    |> join_associations(necessity_by_association)
    |> preload(:contract_address)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      %Token{} = token ->
        {:ok, token}

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

  @spec erc721_or_erc1155_token_instance_from_token_id_and_token_address(binary(), Hash.Address.t()) ::
          {:ok, Instance.t()} | {:error, :not_found}
  def erc721_or_erc1155_token_instance_from_token_id_and_token_address(token_id, token_contract_address) do
    query =
      from(i in Instance, where: i.token_contract_address_hash == ^token_contract_address and i.token_id == ^token_id)

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
    if address_hash !== %{} do
      address_hash
      |> CurrentTokenBalance.last_token_balance(token_contract_address_hash) || Decimal.new(0)
    else
      Decimal.new(0)
    end
  end

  # @spec fetch_last_token_balance_1155(Hash.Address.t(), Hash.Address.t()) :: Decimal.t()
  def fetch_last_token_balance_1155(address_hash, token_contract_address_hash, token_id) do
    if address_hash !== %{} do
      address_hash
      |> CurrentTokenBalance.last_token_balance_1155(token_contract_address_hash, token_id) || Decimal.new(0)
    else
      Decimal.new(0)
    end
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

  def get_token_balance(address_hash, token_contract_address_hash, block_number) do
    query = TokenBalance.fetch_token_balance(address_hash, token_contract_address_hash, block_number)

    Repo.one(query)
  end

  def get_coin_balance(address_hash, block_number) do
    query = CoinBalance.fetch_coin_balance(address_hash, block_number)

    Repo.one(query)
  end

  @spec address_to_balances_by_day(Hash.Address.t(), true | false) :: [balance_by_day]
  def address_to_balances_by_day(address_hash, api? \\ false) do
    latest_block_timestamp =
      address_hash
      |> CoinBalance.last_coin_balance_timestamp()
      |> Repo.one()

    address_hash
    |> CoinBalanceDaily.balances_by_day()
    |> Repo.all()
    |> Enum.sort_by(fn %{date: d} -> {d.year, d.month, d.day} end)
    |> replace_last_value(latest_block_timestamp)
    |> normalize_balances_by_day(api?)
  end

  # https://github.com/blockscout/blockscout/issues/2658
  defp replace_last_value(items, %{value: value, timestamp: timestamp}) do
    List.replace_at(items, -1, %{date: Date.convert!(timestamp, Calendar.ISO), value: value})
  end

  defp replace_last_value(items, _), do: items

  defp normalize_balances_by_day(balances_by_day, api?) do
    result =
      balances_by_day
      |> Enum.filter(fn day -> day.value end)
      |> (&if(api?, do: &1, else: Enum.map(&1, fn day -> Map.update!(day, :date, fn x -> to_string(x) end) end))).()
      |> (&if(api?, do: &1, else: Enum.map(&1, fn day -> Map.update!(day, :value, fn x -> Wei.to(x, :ether) end) end))).()

    today = Date.to_string(NaiveDateTime.utc_now())

    if Enum.count(result) > 0 && !Enum.any?(result, fn map -> map[:date] == today end) do
      List.flatten([result | [%{date: today, value: List.last(result)[:value]}]])
    else
      result
    end
  end

  @spec fetch_token_holders_from_token_hash(Hash.Address.t(), boolean(), [paging_options]) :: [TokenBalance.t()]
  def fetch_token_holders_from_token_hash(contract_address_hash, from_api, options \\ []) do
    query =
      contract_address_hash
      |> CurrentTokenBalance.token_holders_ordered_by_value(options)

    if from_api do
      query
      |> Repo.replica().all()
    else
      query
      |> Repo.all()
    end
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
      Decimal.compare(Enum.at(result, 0), 1) == :eq
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
  Checks if a `t:Explorer.Chain.TokenTransfer.t/0` of type ERC-721 with the given `hash` and `token_id` exists.

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
  Checks if a `t:Explorer.Chain.TokenTransfer.t/0` of type ERC-721 or ERC-1155 with the given `hash` and `token_id` exists.

  Returns `:ok` if found

      iex> contract_address = insert(:address)
      iex> token_id = 10
      iex> insert(:token_transfer,
      ...>  from_address: contract_address,
      ...>  token_contract_address: contract_address,
      ...>  token_id: token_id
      ...> )
      iex> Explorer.Chain.check_erc721_or_erc1155_token_instance_exists(token_id, contract_address.hash)
      :ok

      iex> contract_address = insert(:address)
      iex> token_id = 10
      iex> insert(:token_transfer,
      ...>  from_address: contract_address,
      ...>  token_contract_address: contract_address,
      ...>  token_ids: [token_id]
      ...> )
      iex> Explorer.Chain.check_erc721_or_erc1155_token_instance_exists(token_id, contract_address.hash)
      :ok

  Returns `:not_found` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.check_erc721_or_erc1155_token_instance_exists(10, hash)
      :not_found
  """
  @spec check_erc721_or_erc1155_token_instance_exists(binary() | non_neg_integer(), Hash.Address.t()) ::
          :ok | :not_found
  def check_erc721_or_erc1155_token_instance_exists(token_id, hash) do
    token_id
    |> erc721_or_erc1155_token_instance_exist?(hash)
    |> boolean_to_check_result()
  end

  @doc """
  Checks if a `t:Explorer.Chain.TokenTransfer.t/0` of type ERC-721 with the given `hash` and `token_id` exists.

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

  @doc """
  Checks if a `t:Explorer.Chain.TokenTransfer.t/0` of type ERC-721 or ERC-1155 with the given `hash` and `token_id` exists.

  Returns `true` if found

      iex> contract_address = insert(:address)
      iex> token_id = 10
      iex> insert(:token_transfer,
      ...>  from_address: contract_address,
      ...>  token_contract_address: contract_address,
      ...>  token_id: token_id
      ...> )
      iex> Explorer.Chain.erc721_or_erc1155_token_instance_exist?(token_id, contract_address.hash)
      true

      iex> contract_address = insert(:address)
      iex> token_id = 10
      iex> insert(:token_transfer,
      ...>  from_address: contract_address,
      ...>  token_contract_address: contract_address,
      ...>  token_ids: [token_id]
      ...> )
      iex> Explorer.Chain.erc721_or_erc1155_token_instance_exist?(token_id, contract_address.hash)
      true

  Returns `false` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      iex> Explorer.Chain.erc721_or_erc1155_token_instance_exist?(10, hash)
      false
  """
  @spec erc721_or_erc1155_token_instance_exist?(binary() | non_neg_integer(), Hash.Address.t()) :: boolean()
  def erc721_or_erc1155_token_instance_exist?(token_id, hash) do
    query =
      from(tt in TokenTransfer,
        where:
          tt.token_contract_address_hash == ^hash and
            (tt.token_id == ^token_id or fragment("? @> ARRAY[?::decimal]", tt.token_ids, ^Decimal.new(token_id)))
      )

    Repo.exists?(query)
  end

  defp boolean_to_check_result(true), do: :ok

  defp boolean_to_check_result(false), do: :not_found

  @doc """
  Fetches the first trace from the Nethermind trace URL.
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

  def proxy_contract?(_address_hash, abi) when is_nil(abi), do: false

  def gnosis_safe_contract?(abi) when not is_nil(abi) do
    implementation_method_abi =
      abi
      |> Enum.find(fn method ->
        master_copy_pattern?(method)
      end)

    if implementation_method_abi, do: true, else: false
  end

  def gnosis_safe_contract?(abi) when is_nil(abi), do: false

  @spec get_implementation_address_hash(Hash.Address.t(), list()) :: {String.t() | nil, String.t() | nil}
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

    implementation_address =
      cond do
        implementation_method_abi ->
          get_implementation_address_hash_basic(proxy_address_hash, abi)

        master_copy_method_abi ->
          get_implementation_address_hash_from_master_copy_pattern(proxy_address_hash)

        true ->
          get_implementation_address_hash_eip_1967(proxy_address_hash)
      end

    save_implementation_name(implementation_address, proxy_address_hash)
  end

  def get_implementation_address_hash(proxy_address_hash, abi) when is_nil(proxy_address_hash) or is_nil(abi) do
    {nil, nil}
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
        when empty_address in ["0x", "0x0", "0x0000000000000000000000000000000000000000000000000000000000000000"] ->
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
      when empty_address in ["0x", "0x0", "0x0000000000000000000000000000000000000000000000000000000000000000"] ->
        fetch_openzeppelin_proxy_implementation(proxy_address_hash, json_rpc_named_arguments)

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

  # changes requested by https://github.com/blockscout/blockscout/issues/5292
  defp fetch_openzeppelin_proxy_implementation(proxy_address_hash, json_rpc_named_arguments) do
    # This is the keccak-256 hash of "org.zeppelinos.proxy.implementation"
    storage_slot_logic_contract_address = "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3"

    case Contract.eth_get_storage_at_request(
           proxy_address_hash,
           storage_slot_logic_contract_address,
           nil,
           json_rpc_named_arguments
         ) do
      {:ok, empty_address}
      when empty_address in ["0x", "0x0", "0x0000000000000000000000000000000000000000000000000000000000000000"] ->
        {:ok, "0x"}

      {:ok, logic_contract_address} ->
        {:ok, logic_contract_address}

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

  defp save_implementation_name(empty_address_hash_string, _)
       when empty_address_hash_string in [
              "0x",
              "0x0",
              "0x0000000000000000000000000000000000000000000000000000000000000000",
              @burn_address_hash_str
            ],
       do: {empty_address_hash_string, nil}

  defp save_implementation_name(implementation_address_hash_string, proxy_address_hash)
       when is_binary(implementation_address_hash_string) do
    with {:ok, address_hash} <- string_to_address_hash(implementation_address_hash_string),
         %SmartContract{name: name} <- address_hash_to_smart_contract(address_hash) do
      SmartContract
      |> where([sc], sc.address_hash == ^proxy_address_hash)
      |> update(set: [implementation_name: ^name])
      |> Repo.update_all([])

      {implementation_address_hash_string, name}
    else
      _ ->
        {implementation_address_hash_string, nil}
    end
  end

  defp save_implementation_name(other, _), do: {other, nil}

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
    {implementation_address_hash_string, _name} = get_implementation_address_hash(proxy_address_hash, abi)
    get_implementation_abi(implementation_address_hash_string)
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
      filtered_block_numbers = EthereumJSONRPC.block_numbers_in_range([block_number])
      {:ok, traces} = fetch_block_internal_transactions(filtered_block_numbers, json_rpc_named_arguments)

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
    query =
      from(block in Block,
        where: fragment("DATE(timestamp) = TO_DATE(?, 'YYYY-MM-DD')", ^date),
        select: max(block.number)
      )

    query
    |> Repo.one()
  end

  def is_address_hash_is_smart_contract?(nil), do: false

  def is_address_hash_is_smart_contract?(address_hash) do
    with %Address{contract_code: bytecode} <- Repo.get_by(Address, hash: address_hash),
         false <- is_nil(bytecode) do
      true
    else
      _ ->
        false
    end
  end

  def hash_to_lower_case_string(hash) do
    hash
    |> to_string()
    |> String.downcase()
  end

  def recent_transactions(options, [:pending | _], method_id_filter, type_filter_options) do
    recent_pending_transactions(options, false, method_id_filter, type_filter_options)
  end

  def recent_transactions(options, _, method_id_filter, type_filter_options) do
    recent_collated_transactions(false, options, method_id_filter, type_filter_options)
  end

  def apply_filter_by_method_id_to_transactions(query, filter) when is_list(filter) do
    method_ids = Enum.flat_map(filter, &map_name_or_method_id_to_method_id/1)

    if method_ids != [] do
      query
      |> where([tx], fragment("SUBSTRING(? FOR 4)", tx.input) in ^method_ids)
    else
      query
    end
  end

  def apply_filter_by_method_id_to_transactions(query, filter),
    do: apply_filter_by_method_id_to_transactions(query, [filter])

  defp map_name_or_method_id_to_method_id(string) when is_binary(string) do
    if id = @method_name_to_id_map[string] do
      decode_method_id(id)
    else
      trimmed =
        string
        |> String.replace("0x", "", global: false)

      decode_method_id(trimmed)
    end
  end

  defp decode_method_id(method_id) when is_binary(method_id) do
    case String.length(method_id) == 8 && Base.decode16(method_id, case: :mixed) do
      {:ok, bytes} ->
        [bytes]

      _ ->
        []
    end
  end

  def apply_filter_by_tx_type_to_transactions(query, [_ | _] = filter) do
    {dynamic, modified_query} = apply_filter_by_tx_type_to_transactions_inner(filter, query)

    modified_query
    |> where(^dynamic)
  end

  def apply_filter_by_tx_type_to_transactions(query, _filter), do: query

  def apply_filter_by_tx_type_to_transactions_inner(dynamic \\ dynamic(false), filter, query)

  def apply_filter_by_tx_type_to_transactions_inner(dynamic, [type | remain], query) do
    case type do
      :contract_call ->
        dynamic
        |> filter_contract_call_dynamic()
        |> apply_filter_by_tx_type_to_transactions_inner(
          remain,
          join(query, :inner, [tx], address in assoc(tx, :to_address), as: :to_address)
        )

      :contract_creation ->
        dynamic
        |> filter_contract_creation_dynamic()
        |> apply_filter_by_tx_type_to_transactions_inner(remain, query)

      :coin_transfer ->
        dynamic
        |> filter_transaction_dynamic()
        |> apply_filter_by_tx_type_to_transactions_inner(remain, query)

      :token_transfer ->
        dynamic
        |> filter_token_transfer_dynamic()
        |> apply_filter_by_tx_type_to_transactions_inner(remain, query)

      :token_creation ->
        dynamic
        |> filter_token_creation_dynamic()
        |> apply_filter_by_tx_type_to_transactions_inner(
          remain,
          join(query, :inner, [tx], token in Token,
            on: token.contract_address_hash == tx.created_contract_address_hash,
            as: :created_token
          )
        )
    end
  end

  def apply_filter_by_tx_type_to_transactions_inner(dynamic_query, _, query), do: {dynamic_query, query}

  def filter_contract_creation_dynamic(dynamic) do
    dynamic([tx], ^dynamic or is_nil(tx.to_address_hash))
  end

  def filter_transaction_dynamic(dynamic) do
    dynamic([tx], ^dynamic or tx.value > ^0)
  end

  def filter_contract_call_dynamic(dynamic) do
    dynamic([tx, to_address: to_address], ^dynamic or not is_nil(to_address.contract_code))
  end

  def filter_token_transfer_dynamic(dynamic) do
    # TokenTransfer.__struct__.__meta__.source
    dynamic(
      [tx],
      ^dynamic or
        fragment(
          "NOT (SELECT transaction_hash FROM token_transfers WHERE transaction_hash = ? LIMIT 1) IS NULL",
          tx.hash
        )
    )
  end

  def filter_token_creation_dynamic(dynamic) do
    dynamic([tx, created_token: created_token], ^dynamic or (is_nil(tx.to_address_hash) and not is_nil(created_token)))
  end

  @spec verified_contracts([
          paging_options | necessity_by_association_option | {:filter, :solidity | :vyper} | {:search, String.t()}
        ]) :: [SmartContract.t()]
  def verified_contracts(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    filter = Keyword.get(options, :filter, nil)
    search_string = Keyword.get(options, :search, nil)

    query = from(contract in SmartContract, select: contract, order_by: [desc: :id])

    query
    |> filter_contracts(filter)
    |> search_contracts(search_string)
    |> handle_verified_contracts_paging_options(paging_options)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  defp search_contracts(basic_query, nil), do: basic_query

  defp search_contracts(basic_query, search_string) do
    from(contract in basic_query,
      where:
        ilike(contract.name, ^"%#{search_string}%") or
          ilike(fragment("'0x' || encode(?, 'hex')", contract.address_hash), ^"%#{search_string}%")
    )
  end

  defp filter_contracts(basic_query, :solidity) do
    basic_query
    |> where(is_vyper_contract: ^false)
  end

  defp filter_contracts(basic_query, :vyper) do
    basic_query
    |> where(is_vyper_contract: ^true)
  end

  defp filter_contracts(basic_query, _), do: basic_query

  def count_verified_contracts do
    Repo.aggregate(SmartContract, :count, timeout: :infinity)
  end

  def count_new_verified_contracts do
    query =
      from(contract in SmartContract,
        select: contract.inserted_at,
        where: fragment("NOW() - ? at time zone 'UTC' <= interval '24 hours'", contract.inserted_at)
      )

    query
    |> Repo.aggregate(:count, timeout: :infinity)
  end

  def count_contracts do
    query =
      from(address in Address,
        select: address,
        where: not is_nil(address.contract_code)
      )

    query
    |> Repo.aggregate(:count, timeout: :infinity)
  end

  def count_new_contracts do
    query =
      from(tx in Transaction,
        select: tx,
        where:
          tx.status == ^:ok and
            fragment("NOW() - ? at time zone 'UTC' <= interval '24 hours'", tx.created_contract_code_indexed_at)
      )

    query
    |> Repo.aggregate(:count, timeout: :infinity)
  end

  def count_verified_contracts_from_cache do
    VerifiedContractsCounter.fetch()
  end

  def count_new_verified_contracts_from_cache do
    NewVerifiedContractsCounter.fetch()
  end

  def count_contracts_from_cache do
    ContractsCounter.fetch()
  end

  def count_new_contracts_from_cache do
    NewContractsCounter.fetch()
  end
end
