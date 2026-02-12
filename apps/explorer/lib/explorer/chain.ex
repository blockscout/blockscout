defmodule Explorer.Chain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query,
    only: [
      dynamic: 2,
      from: 2,
      join: 4,
      join: 5,
      limit: 2,
      order_by: 2,
      order_by: 3,
      preload: 2,
      preload: 3,
      select: 3,
      subquery: 1,
      where: 2,
      where: 3
    ]

  require Logger

  alias ABI.TypeDecoder

  alias EthereumJSONRPC.Utility.RangesHelper

  alias Explorer.Chain

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Address.CoinBalanceDaily,
    Address.CurrentTokenBalance,
    Address.TokenBalance,
    Block,
    BlockNumberHelper,
    CurrencyHelper,
    Data,
    Hash,
    Import,
    InternalTransaction,
    Log,
    PendingOperationsHelper,
    PendingTransactionOperation,
    SmartContract,
    Token,
    TokenTransfer,
    Transaction,
    Wei,
    Withdrawal
  }

  alias Explorer.Chain.Block.Reader.General, as: BlockReaderGeneral

  alias Explorer.Chain.Cache.{
    BlockNumber,
    Blocks,
    Uncles
  }

  alias Explorer.Chain.Cache.Counters.{
    BlocksCount,
    ContractsCount,
    NewContractsCount,
    NewVerifiedContractsCount,
    PendingBlockOperationCount,
    PendingTransactionOperationCount,
    VerifiedContractsCount
  }

  alias Explorer.Chain.Cache.Counters.Helper, as: CacheCountersHelper
  alias Explorer.Chain.Health.Helper, as: HealthHelper
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Helper, as: ExplorerHelper

  alias Explorer.Market.MarketHistoryCache
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.{PagingOptions, Repo}

  alias Dataloader.Ecto, as: DataloaderEcto

  @default_page_size 50
  @default_paging_options %PagingOptions{page_size: @default_page_size}

  @token_transfers_per_transaction_preview 10

  @revert_msg_prefix_1 "Revert: "
  @revert_msg_prefix_2 "revert: "
  @revert_msg_prefix_3 "reverted "
  @revert_msg_prefix_4 "Reverted "
  # Geth-like node
  @revert_msg_prefix_5 "execution reverted: "
  @revert_msg_prefix_6_empty "execution reverted"

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

  @type necessity_by_association_option :: {:necessity_by_association, necessity_by_association}
  @type paging_options :: {:paging_options, PagingOptions.t()}
  @typep balance_by_day :: %{date: String.t(), value: Wei.t()}
  @type api? :: {:api?, true | false}
  @type ip :: {:ip, String.t()}
  @type show_scam_tokens? :: {:show_scam_tokens?, true | false}

  def wrapped_union_subquery(query) do
    from(
      q in subquery(query),
      select: q
    )
  end

  @spec address_hash_to_token_transfers(Hash.Address.t(), Keyword.t()) :: [Transaction.t()]
  def address_hash_to_token_transfers(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0, 0}, is_index_in_asc_order: false} ->
        []

      _ ->
        direction = Keyword.get(options, :direction)

        direction
        |> Transaction.transactions_with_token_transfers_direction(address_hash)
        |> Transaction.preload_token_transfers(address_hash)
        |> Transaction.handle_paging_options(paging_options)
        |> Repo.all()
    end
  end

  @spec address_hash_to_token_transfers_new(Hash.Address.t() | String.t(), Keyword.t()) :: [TokenTransfer.t()]
  def address_hash_to_token_transfers_new(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    direction = Keyword.get(options, :direction)
    token_address_hash = Keyword.get(options, :token_address_hash)
    filters = Keyword.get(options, :token_type)
    necessity_by_association = Keyword.get(options, :necessity_by_association)

    address_hash
    |> TokenTransfer.token_transfers_by_address_hash(direction, token_address_hash, filters, paging_options, options)
    |> join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  @spec address_hash_to_withdrawals(
          Hash.Address.t(),
          [paging_options | necessity_by_association_option]
        ) :: [Withdrawal.t()]
  def address_hash_to_withdrawals(address_hash, options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    address_hash
    |> Withdrawal.address_hash_to_withdrawals_query()
    |> join_associations(necessity_by_association)
    |> handle_withdrawals_paging_options(paging_options)
    |> select_repo(options).all()
  end

  @spec address_to_logs(Hash.Address.t(), [paging_options | necessity_by_association_option | api?]) :: [Log.t()]
  def address_to_logs(address_hash, csv_export?, options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options) || %PagingOptions{page_size: 50}
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    case paging_options do
      %PagingOptions{key: {0, 0}} ->
        []

      _ ->
        from_block = from_block(options)
        to_block = to_block(options)

        base =
          from(log in Log,
            order_by: [desc: log.block_number, desc: log.index],
            where: log.address_hash == ^address_hash,
            limit: ^paging_options.page_size,
            select: log,
            inner_join: block in Block,
            on: block.hash == log.block_hash,
            where: block.consensus == true
          )

        preloaded_query =
          if csv_export? do
            base
          else
            base
            |> preload(
              transaction: [
                from_address: ^Implementation.proxy_implementations_association(),
                to_address: ^Implementation.proxy_implementations_association()
              ]
            )
          end

        preloaded_query
        |> page_logs(paging_options)
        |> filter_topic(Keyword.get(options, :topic))
        |> BlockReaderGeneral.where_block_number_in_period(from_block, to_block)
        |> join_associations(necessity_by_association)
        |> select_repo(options).all()
        |> Enum.take(paging_options.page_size)
    end
  end

  defp filter_topic(base_query, null) when null in [nil, "", "null"], do: base_query

  defp filter_topic(base_query, topic) do
    from(log in base_query,
      where:
        log.first_topic == ^topic or log.second_topic == ^topic or log.third_topic == ^topic or
          log.fourth_topic == ^topic
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

    case paging_options do
      %PagingOptions{key: {0, 0}, is_index_in_asc_order: false} ->
        []

      _ ->
        address_hash
        |> Transaction.transactions_with_token_transfers(token_hash)
        |> Transaction.preload_token_transfers(address_hash)
        |> Transaction.handle_paging_options(paging_options)
        |> Repo.all()
    end
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
  Finds all `t:Explorer.Chain.Transaction.t/0`s in the `t:Explorer.Chain.Block.t/0`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{index}`) and. Results will be the transactions older than
      the `index` that are passed.
  """
  @spec block_to_transactions(Hash.Full.t(), [paging_options | necessity_by_association_option | api?()], true | false) ::
          [
            Transaction.t()
          ]
  def block_to_transactions(block_hash, options \\ [], old_ui? \\ true) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    type_filter = Keyword.get(options, :type)

    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions_in_ascending_order_by_index()
    |> join(:inner, [transaction], block in assoc(transaction, :block))
    |> where([_, block], block.hash == ^block_hash)
    |> Transaction.apply_filter_by_type_to_transactions(type_filter)
    |> join_associations(necessity_by_association)
    |> Transaction.put_has_token_transfers_to_transaction(old_ui?)
    |> (&if(old_ui?, do: preload(&1, [{:token_transfers, [:token, :from_address, :to_address]}]), else: &1)).()
    |> select_repo(options).all()
  end

  @spec execution_node_to_transactions(Hash.Address.t(), [paging_options | necessity_by_association_option | api?()]) ::
          [Transaction.t()]
  def execution_node_to_transactions(execution_node_hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions_in_descending_order_by_block_and_index()
    |> where(execution_node_hash: ^execution_node_hash)
    |> join_associations(necessity_by_association)
    |> Transaction.put_has_token_transfers_to_transaction(false)
    |> (& &1).()
    |> select_repo(options).all()
  end

  @spec block_to_withdrawals(
          Hash.Full.t(),
          [paging_options | necessity_by_association_option]
        ) :: [Withdrawal.t()]
  def block_to_withdrawals(block_hash, options \\ []) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    block_hash
    |> Withdrawal.block_hash_to_withdrawals_query()
    |> join_associations(necessity_by_association)
    |> handle_withdrawals_paging_options(paging_options)
    |> select_repo(options).all()
  end

  @doc """
  Finds sum of gas_used for new (EIP-1559) transactions belongs to block
  """
  @spec block_to_gas_used_by_1559_transactions(Hash.Full.t()) :: non_neg_integer()
  def block_to_gas_used_by_1559_transactions(block_hash) do
    query =
      from(
        transaction in Transaction,
        where: transaction.block_hash == ^block_hash,
        select: sum(transaction.gas_used)
      )

    result = Repo.one(query)
    if result, do: result, else: 0
  end

  @doc """
  Finds sum of priority fee for new (EIP-1559) transactions belongs to block
  """
  @spec block_to_priority_fee_of_1559_transactions(Hash.Full.t()) :: Decimal.t()
  def block_to_priority_fee_of_1559_transactions(block_hash) do
    block = Repo.get_by(Block, hash: block_hash)

    case block.base_fee_per_gas do
      %Wei{value: base_fee_per_gas} ->
        query =
          from(
            transaction in Transaction,
            where: transaction.block_hash == ^block_hash,
            select:
              sum(
                fragment(
                  "CASE
                    WHEN COALESCE(?,?) = 0 THEN 0
                    WHEN COALESCE(?,?) - ? < COALESCE(?,?) THEN (COALESCE(?,?) - ?) * ?
                    ELSE COALESCE(?,?) * ? END",
                  transaction.max_fee_per_gas,
                  transaction.gas_price,
                  transaction.max_fee_per_gas,
                  transaction.gas_price,
                  ^base_fee_per_gas,
                  transaction.max_priority_fee_per_gas,
                  transaction.gas_price,
                  transaction.max_fee_per_gas,
                  transaction.gas_price,
                  ^base_fee_per_gas,
                  transaction.gas_used,
                  transaction.max_priority_fee_per_gas,
                  transaction.gas_price,
                  transaction.gas_used
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

  @spec check_if_withdrawals_in_block(Hash.Full.t()) :: boolean()
  def check_if_withdrawals_in_block(block_hash, options \\ []) do
    block_hash
    |> Withdrawal.block_hash_to_withdrawals_unordered_query()
    |> select_repo(options).exists?()
  end

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

  @spec verified_contracts_top(non_neg_integer()) :: [Hash.Address.t()]
  def verified_contracts_top(limit) do
    query =
      from(contract in SmartContract,
        inner_join: address in Address,
        on: contract.address_hash == address.hash,
        order_by: [desc: address.fetched_coin_balance],
        limit: ^limit,
        select: contract.address_hash
      )

    Repo.all(query)
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
  Checks to see if the chain is down indexing based on the transaction from the
  oldest block and the pending operation
  """
  @spec finished_indexing_internal_transactions?([api?]) :: boolean()
  def finished_indexing_internal_transactions?(options \\ []) do
    if indexer_running?() and internal_transactions_fetcher_running?() do
      json_rpc_named_arguments = Application.fetch_env!(:indexer, :json_rpc_named_arguments)
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      if variant == EthereumJSONRPC.Anvil do
        true
      else
        check_left_blocks_to_index_internal_transactions(options)
      end
    else
      true
    end
  end

  defp check_left_blocks_to_index_internal_transactions(options) do
    with {:transactions_exist, true} <- {:transactions_exist, select_repo(options).exists?(Transaction)},
         min_block_number when not is_nil(min_block_number) <-
           select_repo(options).aggregate(Transaction, :min, :block_number) do
      min_block_number =
        min_block_number
        |> Decimal.max(Application.get_env(:indexer, :trace_first_block))
        |> Decimal.to_integer()

      query =
        case PendingOperationsHelper.pending_operations_type() do
          "blocks" ->
            from(
              block in Block,
              join: pending_ops in assoc(block, :pending_operations),
              where: block.consensus and block.number == ^min_block_number
            )

          "transactions" ->
            from(
              pto in PendingTransactionOperation,
              join: t in assoc(pto, :transaction),
              where: t.block_consensus and t.block_number == ^min_block_number
            )
        end

      if select_repo(options).exists?(query) do
        false
      else
        check_indexing_internal_transactions_threshold()
      end
    else
      {:transactions_exist, false} -> true
      nil -> false
    end
  end

  defp check_indexing_internal_transactions_threshold do
    pending_ops_count =
      case PendingOperationsHelper.pending_operations_type() do
        "blocks" -> PendingBlockOperationCount.get()
        "transactions" -> PendingTransactionOperationCount.get()
      end

    if pending_ops_count <
         Application.get_env(:indexer, Indexer.Fetcher.InternalTransaction)[:indexing_finished_threshold] do
      true
    else
      false
    end
  end

  @doc """
  Checks if indexing of blocks finished based on the ratio of indexed blocks to blockchain height
  """
  @spec finished_indexing_from_ratio?(Decimal.t()) :: boolean()
  def finished_indexing_from_ratio?(ratio) do
    Decimal.compare(ratio, 1) !== :lt
  end

  @doc """
  Checks if indexing of blocks and internal transactions finished aka full indexing
  """
  @spec finished_indexing?([api?]) :: boolean()
  def finished_indexing?(options \\ []) do
    if indexer_running?() do
      indexed_ratio = indexed_ratio_blocks()

      case finished_indexing_from_ratio?(indexed_ratio) do
        false -> false
        _ -> finished_indexing_internal_transactions?(options)
      end
    else
      true
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

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.Address.create(
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

  """
  @spec hash_to_address(Hash.Address.t() | binary(), [necessity_by_association_option | api?]) ::
          {:ok, Address.t()} | {:error, :not_found}
  def hash_to_address(
        hash,
        options \\ [
          necessity_by_association: %{
            :names => :optional,
            :smart_contract => :optional,
            :token => :optional,
            Address.contract_creation_transaction_associations() => :optional
          }
        ]
      ) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query = Address.address_query(hash)

    query
    |> join_associations(necessity_by_association)
    |> select_repo(options).one()
    |> SmartContract.compose_address_for_unverified_smart_contract(hash, options)
    |> case do
      nil -> {:error, :not_found}
      address -> {:ok, address}
    end
  end

  @doc """
  Converts `t:Explorer.Chain.Address.t/0` `hash` to the `t:Explorer.Chain.Address.t/0` with that `hash`.

  Returns `{:ok, %Explorer.Chain.Address{}}` if found

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.Address.create(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> {:ok, %Explorer.Chain.Address{hash: found_hash}} = Explorer.Chain.hash_to_address(hash)
      iex> found_hash == hash
      true

  Returns `{:error, address}` if not found but created an address

      iex> {:ok, %Explorer.Chain.Address{hash: hash}} = Explorer.Chain.Address.create(
      ...>   %{hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"}
      ...> )
      iex> {:ok, %Explorer.Chain.Address{hash: found_hash}} = Explorer.Chain.hash_to_address(hash)
      iex> found_hash == hash
      true


  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Address.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.Address.t/0` will not be included in the list.

  """
  @spec find_or_insert_address_from_hash(Hash.Address.t(), [necessity_by_association_option]) ::
          {:ok, Address.t()}
  def find_or_insert_address_from_hash(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = hash,
        options \\ [
          necessity_by_association: %{
            :names => :optional,
            :smart_contract => :optional,
            :token => :optional,
            Address.contract_creation_transaction_associations() => :optional
          }
        ]
      ) do
    case hash_to_address(hash, options) do
      {:ok, address} ->
        {:ok, address}

      {:error, :not_found} ->
        Address.create(%{hash: to_string(hash)})
        hash_to_address(hash, options)
    end
  end

  @doc """
  Converts list of `t:Explorer.Chain.Address.t/0` `hash` to the `t:Explorer.Chain.Address.t/0` with that `hash`.

  Returns `[%Explorer.Chain.Address{}]` if found

  """
  @spec hashes_to_addresses([Hash.Address.t()], [necessity_by_association_option | api?]) :: [Address.t()]
  def hashes_to_addresses(hashes, options \\ [])

  def hashes_to_addresses([], _), do: []

  def hashes_to_addresses(hashes, options) when is_list(hashes) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    hashes
    |> hashes_to_addresses_query()
    |> join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  @doc """
  Generates a query to convert a list of hashes to their corresponding addresses.

  ## Parameters

    - hashes: A list of hashes to be converted.

  ## Returns

    - A query that can be executed to retrieve the addresses corresponding to the provided hashes.
  """
  @spec hashes_to_addresses_query([Hash.Address.t()]) :: Ecto.Query.t()
  def hashes_to_addresses_query(hashes) do
    from(
      address in Address,
      as: :address,
      where: address.hash in ^hashes,
      # https://stackoverflow.com/a/29598910/470451
      order_by: fragment("array_position(?, ?)", type(^hashes, {:array, Hash.Address}), address.hash)
    )
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

      iex> {:ok, hash} = Explorer.Chain.string_to_full_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.hash_to_block(hash)
      {:error, :not_found}

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Block.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Block.t/0` will not be included in the page `entries`.

  """
  @spec hash_to_block(Hash.Full.t(), [necessity_by_association_option | api?]) ::
          {:ok, Block.t()} | {:error, :not_found}
  def hash_to_block(%Hash{byte_count: unquote(Hash.Full.byte_count())} = hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Block
    |> where(hash: ^hash)
    |> join_associations(necessity_by_association)
    |> select_repo(options).one()
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

      iex> {:ok, hash} = Explorer.Chain.string_to_full_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.hash_to_transaction(hash)
      {:error, :not_found}

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
  """
  @spec hash_to_transaction(Hash.Full.t(), [necessity_by_association_option | api?]) ::
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
    |> select_repo(options).one()
    |> case do
      nil ->
        {:error, :not_found}

      transaction ->
        {:ok, transaction}
    end
  end

  def preload_token_transfers(
        %Transaction{hash: transaction_hash, block_hash: block_hash} = transaction,
        necessity_by_association,
        options
      ) do
    limit = @token_transfers_per_transaction_preview + 1

    token_transfers =
      TokenTransfer
      |> (&if(is_nil(block_hash),
            do: where(&1, [token_transfer], token_transfer.transaction_hash == ^transaction_hash),
            else:
              where(
                &1,
                [token_transfer],
                token_transfer.transaction_hash == ^transaction_hash and token_transfer.block_hash == ^block_hash
              )
          )).()
      |> limit(^limit)
      |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
      |> order_by([token_transfer], asc: token_transfer.log_index)
      |> join_associations(necessity_by_association)
      |> select_repo(options).all()
      |> flat_1155_batch_token_transfers()
      |> Enum.take(limit)

    %Transaction{transaction | token_transfers: token_transfers}
  end

  def get_token_transfers_per_transaction_preview_count, do: @token_transfers_per_transaction_preview

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

      iex> {:ok, hash} = Explorer.Chain.string_to_full_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.hashes_to_transactions([hash])
      []

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, index}`) and. Results will be the transactions
      older than the `block_number` and `index` that are passed.
  """
  @spec hashes_to_transactions([Hash.Full.t()], [paging_options | necessity_by_association_option | api?]) ::
          [Transaction.t()] | []
  def hashes_to_transactions(hashes, options \\ []) when is_list(hashes) and is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    # Don't use @default_paging_options to preserve backward compatibility
    paging_options = Keyword.get(options, :paging_options, false)

    transactions =
      if paging_options do
        case paging_options do
          %PagingOptions{key: {0, 0}, is_index_in_asc_order: false} -> []
          _ -> Transaction.fetch_transactions(paging_options)
        end
      else
        Transaction.fetch_transactions()
      end

    transactions
    |> where([transaction], transaction.hash in ^hashes)
    |> join_associations(necessity_by_association)
    |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
    |> select_repo(options).all()
  end

  @doc """
  Bulk insert all data stored in the `Explorer`.

  See `Explorer.Chain.Import.all/1` for options and returns.
  """
  @spec import(Import.all_options()) :: Import.all_result()
  def import(options) do
    case Import.all(options) do
      {:ok, imported} = result ->
        assets_to_import = %{
          addresses: imported[:addresses] || [],
          blocks: imported[:blocks] || [],
          transactions: imported[:transactions] || [],
          address_current_token_balances: imported[:address_current_token_balances] || []
        }

        filtered_addresses_to_import =
          MultichainSearch.filter_addresses_to_multichain_import(assets_to_import[:addresses], options[:broadcast])

        assets_to_import = Map.put(assets_to_import, :addresses, filtered_addresses_to_import)

        MultichainSearch.send_data_to_queue(assets_to_import)

        result

      other_result ->
        other_result
    end
  end

  @doc """
  The percentage of indexed blocks on the chain.

  If there are no blocks, the percentage is 0.

      iex> Explorer.Chain.indexed_ratio_blocks()
      Decimal.new(1)

  """
  @spec indexed_ratio_blocks() :: Decimal.t()
  def indexed_ratio_blocks do
    if indexer_running?() do
      %{min: min_saved_block_number, max: max_saved_block_number} = BlockNumber.get_all()

      min_blockchain_block_number =
        RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :block_ranges))

      case {min_saved_block_number, max_saved_block_number} do
        {0, 0} ->
          Decimal.new(1)

        _ ->
          divisor = max_saved_block_number - min_blockchain_block_number - BlockNumberHelper.null_rounds_count() + 1

          ratio = get_ratio(BlocksCount.get(), divisor)

          ratio
          |> (&if(
                greater_or_equal_0_99(&1) &&
                  min_saved_block_number <= min_blockchain_block_number,
                do: Decimal.new(1),
                else: &1
              )).()
          |> format_indexed_ratio()
      end
    else
      Decimal.new(1)
    end
  end

  @spec indexed_ratio_internal_transactions() :: Decimal.t()
  def indexed_ratio_internal_transactions do
    if indexer_running?() and internal_transactions_fetcher_running?() do
      %{max: max_saved_block_number} = BlockNumber.get_all()

      pending_ops_count =
        case PendingOperationsHelper.pending_operations_type() do
          "blocks" -> PendingBlockOperationCount.get()
          "transactions" -> PendingTransactionOperationCount.get()
        end

      min_blockchain_trace_block_number = Application.get_env(:indexer, :trace_first_block)

      case max_saved_block_number do
        0 ->
          Decimal.new(0)

        _ ->
          full_blocks_range =
            max_saved_block_number - min_blockchain_trace_block_number - BlockNumberHelper.null_rounds_count() + 1

          processed_int_transactions_for_blocks_count = max(0, full_blocks_range - pending_ops_count)

          ratio = get_ratio(processed_int_transactions_for_blocks_count, full_blocks_range)

          ratio
          |> (&if(
                greater_or_equal_0_99(&1),
                do: Decimal.new(1),
                else: &1
              )).()
          |> format_indexed_ratio()
      end
    else
      Decimal.new(1)
    end
  end

  @spec get_ratio(non_neg_integer(), non_neg_integer()) :: Decimal.t()
  defp get_ratio(dividend, divisor) do
    if divisor > 0,
      do: dividend |> Decimal.div(divisor),
      else: Decimal.new(1)
  end

  @spec greater_or_equal_0_99(Decimal.t()) :: boolean()
  defp greater_or_equal_0_99(value) do
    Decimal.compare(value, Decimal.from_float(0.99)) == :gt ||
      Decimal.compare(value, Decimal.from_float(0.99)) == :eq
  end

  @spec format_indexed_ratio(Decimal.t()) :: Decimal.t()
  defp format_indexed_ratio(raw_ratio) do
    raw_ratio
    |> Decimal.round(2, :down)
    |> Decimal.min(Decimal.new(1))
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
  @spec list_blocks([paging_options | necessity_by_association_option | api?]) :: [Block.t()]
  def list_blocks(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options) || @default_paging_options
    block_type = Keyword.get(options, :block_type, "Block")

    cond do
      block_type == "Block" && !paging_options.key ->
        block_from_cache(block_type, paging_options, necessity_by_association, options)

      block_type == "Uncle" && !paging_options.key ->
        uncles_from_cache(block_type, paging_options, necessity_by_association, options)

      true ->
        fetch_blocks(block_type, paging_options, necessity_by_association, options)
    end
  end

  defp block_from_cache(block_type, paging_options, necessity_by_association, options) do
    case Blocks.atomic_take_enough(paging_options.page_size) do
      nil ->
        elements = fetch_blocks(block_type, paging_options, necessity_by_association, options)

        Blocks.update(elements)

        elements

      blocks ->
        blocks |> select_repo(options).preload(Map.keys(necessity_by_association))
    end
  end

  defp uncles_from_cache(block_type, paging_options, necessity_by_association, options) do
    case Uncles.atomic_take_enough(paging_options.page_size) do
      nil ->
        elements = fetch_blocks(block_type, paging_options, necessity_by_association, options)

        Uncles.update(elements)

        elements

      blocks ->
        blocks
    end
  end

  defp fetch_blocks(block_type, paging_options, necessity_by_association, options) do
    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        Block
        |> Block.block_type_filter(block_type)
        |> page_blocks(paging_options)
        |> limit(^paging_options.page_size)
        |> order_by(desc: :number)
        |> join_associations(necessity_by_association)
        |> select_repo(options).all()
    end
  end

  @doc """
    Retrieves the total row count for a given table.

    This function estimates the row count using system catalogs. If the estimate
    is unavailable, it performs an exact count using an aggregate query.

    ## Parameters
    - `module`: The module representing the table schema.
    - `options`: An optional keyword list of options, such as selecting a specific repository.

    ## Returns
    - The total row count as a non-negative integer.
  """
  @spec get_table_rows_total_count(atom(), keyword()) :: non_neg_integer()
  def get_table_rows_total_count(module, options) do
    table_name = module.__schema__(:source)

    count = CacheCountersHelper.estimated_count_from(table_name, options)

    if is_nil(count) do
      select_repo(options).aggregate(module, :count, timeout: :infinity)
    else
      count
    end
  end

  @doc """
  Return the balance in usd corresponding to this token. Return nil if the fiat_value of the token is not present.
  """
  def balance_in_fiat(%{fiat_value: fiat_value} = token_balance) when not is_nil(fiat_value) do
    token_balance.fiat_value
  end

  def balance_in_fiat(%{token: %{fiat_value: fiat_value, decimals: decimals}}) when nil in [fiat_value, decimals] do
    nil
  end

  def balance_in_fiat(%{token: %{fiat_value: fiat_value, decimals: decimals}} = token_balance) do
    tokens = CurrencyHelper.divide_decimals(token_balance.value, decimals)
    Decimal.mult(tokens, fiat_value)
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
  @spec max_consensus_block_number(Keyword.t()) :: {:ok, Block.block_number()} | {:error, :not_found}
  def max_consensus_block_number(options \\ [api?: true]) do
    Block
    |> where(consensus: true)
    |> select_repo(options).aggregate(:max, :number)
    |> case do
      nil -> {:error, :not_found}
      number -> {:ok, number}
    end
  end

  @spec block_height() :: block_height()
  def block_height(options \\ []) do
    query = from(block in Block, select: coalesce(max(block.number), 0), where: block.consensus == true)

    select_repo(options).one!(query)
  end

  @spec indexer_running?() :: boolean()
  defp indexer_running? do
    Application.get_env(:indexer, Indexer.Supervisor)[:enabled] or
      match?({:ok, _, _}, HealthHelper.last_db_block_status())
  end

  @spec internal_transactions_fetcher_running?() :: boolean()
  defp internal_transactions_fetcher_running? do
    not Application.get_env(:indexer, Indexer.Fetcher.InternalTransaction.Supervisor)[:disabled?] or
      match?({:ok, _, _}, last_db_internal_transaction_block_status())
  end

  @spec last_db_internal_transaction_block_status() ::
          {:ok, Block.block_number(), DateTime.t()}
          | {:stale, Block.block_number(), DateTime.t()}
          | {:error, :no_blocks}
  defp last_db_internal_transaction_block_status do
    it_query =
      from(internal_transaction in InternalTransaction,
        select: internal_transaction.block_number,
        order_by: [desc: internal_transaction.block_number],
        limit: 1
      )

    last_it_block_number =
      it_query
      |> Repo.one()

    if is_nil(last_it_block_number) do
      {:error, :no_blocks}
    else
      block_query =
        from(block in Block,
          select: {block.number, block.timestamp},
          where: block.consensus == true and block.number == ^last_it_block_number
        )

      block_query
      |> Repo.one()
      |> HealthHelper.block_status()
    end
  end

  def fetch_min_missing_block_cache(from \\ nil, to \\ nil) do
    from_block_number = from || 0
    to_block_number = to || BlockNumber.get_max()

    if to_block_number > 0 do
      query =
        from(b in Block,
          right_join:
            missing_range in fragment(
              """
                (SELECT b1.number
                FROM generate_series((?)::integer, (?)::integer) AS b1(number)
                WHERE NOT EXISTS
                  (SELECT 1 FROM blocks b2 WHERE b2.number=b1.number AND b2.consensus AND NOT b2.refetch_needed))
              """,
              ^from_block_number,
              ^to_block_number
            ),
          on: b.number == missing_range.number,
          select: min(missing_range.number)
        )

      Repo.one(query, timeout: :infinity)
    else
      nil
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
      iex> Explorer.Chain.missing_block_number_ranges(5..0//-1)
      [4..3//-1, 1..1]

  If only non-consensus blocks exist for a number, the number still counts as missing.

      iex> insert(:block, number: 0)
      iex> insert(:block, number: 1, consensus: false)
      iex> insert(:block, number: 2)
      iex> Explorer.Chain.missing_block_number_ranges(2..0//-1)
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

  def missing_block_number_ranges(range_start..range_end//_) do
    range_min = min(range_start, range_end)
    range_max = max(range_start, range_end)

    ordered_missing_query =
      if Application.get_env(:explorer, :chain_type) == :filecoin do
        from(b in Block,
          right_join:
            missing_range in fragment(
              """
              (
                SELECT distinct b1.number
                FROM generate_series((?)::integer, (?)::integer) AS b1(number)
                WHERE NOT EXISTS
                  (SELECT 1 FROM blocks b2 WHERE b2.number=b1.number AND b2.consensus AND NOT b2.refetch_needed)
                AND NOT EXISTS (SELECT 1 FROM null_round_heights nrh where nrh.height=b1.number)
                ORDER BY b1.number DESC
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
      else
        from(b in Block,
          right_join:
            missing_range in fragment(
              """
              (
                SELECT distinct b1.number
                FROM generate_series((?)::integer, (?)::integer) AS b1(number)
                WHERE NOT EXISTS
                  (SELECT 1 FROM blocks b2 WHERE b2.number=b1.number AND b2.consensus AND NOT b2.refetch_needed)
                ORDER BY b1.number DESC
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
      end

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
        if range_start <= range_end, do: first1 <= first2, else: first1 >= first2
      end)
      |> Enum.map(fn %Range{first: first, last: last} = range ->
        if range_start <= range_end do
          range
        else
          set_new_range(last, first)
        end
      end)

    ordered_block_ranges
  end

  defp set_new_range(last, first) do
    if last > first, do: set_range(last, first, -1), else: set_range(last, first, 1)
  end

  defp set_range(last, first, step) do
    %Range{first: last, last: first, step: step}
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
  @spec number_to_block(Block.block_number(), [necessity_by_association_option | api?]) ::
          {:ok, Block.t()} | {:error, :not_found}
  def number_to_block(number, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Block
    |> where(consensus: true, number: ^number)
    |> join_associations(necessity_by_association)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  def default_page_size, do: @default_page_size

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

  @spec string_to_address_hash_or_nil(String.t()) :: Hash.Address.t() | nil
  def string_to_address_hash_or_nil(string) do
    case string_to_address_hash(string) do
      {:ok, hash} -> hash
      :error -> nil
    end
  end

  @doc """
  The `string` must start with `0x`, then is converted to an integer and then to `t:Explorer.Chain.Hash.t/0`.

      iex> Explorer.Chain.string_to_full_hash(
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

      iex> Explorer.Chain.string_to_full_hash("0x0")
      :error

  """
  @spec string_to_full_hash(String.t()) :: {:ok, Hash.t()} | :error
  def string_to_full_hash(string) when is_binary(string) do
    Hash.Full.cast(string)
  end

  def string_to_full_hash(_), do: :error

  @doc """
  Constructs the base query `Ecto.Query.t()/0` to create requests to the transaction logs

  ## Returns

    * The query to the Log table with the joined associated transactions.

  """
  @spec log_with_transactions_query() :: Ecto.Query.t()
  def log_with_transactions_query do
    from(log in Log,
      inner_join: transaction in Transaction,
      on:
        transaction.block_hash == log.block_hash and transaction.block_number == log.block_number and
          transaction.hash == log.transaction_hash
    )
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
  @spec transaction_to_logs(Hash.Full.t(), [paging_options | necessity_by_association_option | api?]) :: [Log.t()]
  def transaction_to_logs(transaction_hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    log_with_transactions_query()
    |> where([_, transaction], transaction.hash == ^transaction_hash)
    |> page_transaction_logs(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([log], asc: log.index)
    |> join_associations(necessity_by_association)
    |> select_repo(options).all()
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
  @spec transaction_to_token_transfers(Hash.Full.t(), [paging_options | necessity_by_association_option | api?()]) :: [
          TokenTransfer.t()
        ]
  def transaction_to_token_transfers(transaction_hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = options |> Keyword.get(:paging_options, @default_paging_options) |> Map.put(:asc_order, true)

    case paging_options do
      %PagingOptions{key: {0, 0}} ->
        []

      _ ->
        token_type = Keyword.get(options, :token_type)

        TokenTransfer
        |> join(:inner, [token_transfer], transaction in assoc(token_transfer, :transaction))
        |> where(
          [token_transfer, transaction],
          transaction.hash == ^transaction_hash and token_transfer.block_hash == transaction.block_hash and
            token_transfer.block_number == transaction.block_number
        )
        |> join(:inner, [tt], token in assoc(tt, :token), as: :token)
        |> preload([token: token], [{:token, token}])
        |> TokenTransfer.filter_by_type(token_type)
        |> ExplorerHelper.maybe_hide_scam_addresses_for_token_transfers(options)
        |> TokenTransfer.page_token_transfer(paging_options)
        |> limit(^paging_options.page_size)
        |> order_by([token_transfer], asc: token_transfer.log_index)
        |> join_associations(necessity_by_association)
        |> select_repo(options).all()
    end
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
      Transaction.fetch_transaction_revert_reason(transaction)
    else
      revert_reason
    end
  end

  @doc """
  Fetches the raw traces of transaction.
  """
  @spec fetch_transaction_raw_traces(map()) :: {:ok, [map()]} | {:error, any()}
  def fetch_transaction_raw_traces(%{hash: hash, block_number: block_number}) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    EthereumJSONRPC.fetch_transaction_raw_traces(
      %{hash: to_string(hash), block_number: block_number},
      json_rpc_named_arguments
    )
  end

  @doc """
  Parses the revert reason from an error returned by JSON RPC node during eth_call.
  Returns the formatted revert reason as a hex or utf8 string.
  Returns `nil` if the revert reason cannot be parsed or error format is unknown.
  """
  @spec parse_revert_reason_from_error(any()) :: String.t() | nil
  def parse_revert_reason_from_error(%{data: data}), do: format_revert_data(data)

  def parse_revert_reason_from_error(%{message: message}), do: format_revert_reason_message(message)

  def parse_revert_reason_from_error(_), do: nil

  defp format_revert_data(revert_data) do
    case revert_data do
      "revert" ->
        ""

      "0x" <> _ ->
        revert_data

      _ ->
        nil
    end
  end

  defp format_revert_reason_message(revert_reason) do
    case revert_reason do
      @revert_msg_prefix_1 <> rest ->
        rest

      @revert_msg_prefix_2 <> rest ->
        rest

      @revert_msg_prefix_3 <> rest ->
        rest

      @revert_msg_prefix_4 <> rest ->
        rest

      @revert_msg_prefix_5 <> rest ->
        rest

      @revert_msg_prefix_6_empty ->
        ""

      _ ->
        nil
    end
  end

  @doc """
  The `t:Explorer.Chain.Transaction.t/0` or `t:Explorer.Chain.InternalTransaction.t/0` `value` of the `transaction` in
  `unit`.
  """
  @spec value(InternalTransaction.t() | Transaction.t(), :wei | :gwei | :ether) :: Wei.wei() | Wei.gwei() | Wei.ether()
  def value(%type{value: value}, unit) when type in [InternalTransaction, Transaction] do
    Wei.to(value, unit)
  end

  @doc """
  Retrieves the bytecode of a smart contract.

  ## Parameters

    - `address_or_hash` (binary() | Hash.Address.t()): The address hash of the smart contract.
    - `options` (api?()): keyword to determine target DB (read replica or primary).

  ## Returns

  - `binary()`: The bytecode of the smart contract.
  """
  @spec smart_contract_bytecode(binary() | Hash.Address.t(), [api?]) :: binary()
  def smart_contract_bytecode(address_hash, options \\ []) do
    address_hash
    |> Address.address_query()
    |> select([address], address.contract_code)
    |> select_repo(options).one()
    |> Data.to_string()
  end

  def smart_contract_creation_transaction_bytecode(address_hash) do
    creation_transaction_query =
      from(
        transaction in Transaction,
        left_join: a in Address,
        on: transaction.created_contract_address_hash == a.hash,
        where: transaction.created_contract_address_hash == ^address_hash,
        where: transaction.status == ^1,
        select: %{init: transaction.input, created_contract_code: a.contract_code},
        order_by: [desc: transaction.block_number],
        limit: ^1
      )

    transaction_input =
      creation_transaction_query
      |> Repo.one()

    if transaction_input do
      with %{init: input, created_contract_code: created_contract_code} <- transaction_input do
        %{init: Data.to_string(input), created_contract_code: Data.to_string(created_contract_code)}
      end
    else
      case address_hash
           |> Address.creation_internal_transaction_query()
           |> Repo.one() do
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
  Fetches contract creation input data from the transaction (not internal transaction).
  """
  @spec contract_creation_input_data_from_transaction(String.t()) :: nil | binary()
  def contract_creation_input_data_from_transaction(address_hash, options \\ []) do
    transaction =
      Transaction
      |> where([transaction], transaction.created_contract_address_hash == ^address_hash)
      |> select_repo(options).one()

    if transaction && transaction.input do
      case Data.dump(transaction.input) do
        {:ok, bytes} ->
          bytes

        _ ->
          nil
      end
    end
  end

  defp fetch_transactions_in_ascending_order_by_index(paging_options) do
    Transaction
    |> order_by([transaction], asc: transaction.index)
    |> handle_block_paging_options(paging_options)
  end

  defp fetch_transactions_in_descending_order_by_block_and_index(paging_options) do
    Transaction
    |> order_by([transaction], desc: transaction.block_number, asc: transaction.index)
    |> handle_block_paging_options(paging_options)
  end

  defp handle_block_paging_options(query, nil), do: query

  defp handle_block_paging_options(query, %PagingOptions{key: nil, page_size: nil}), do: query

  defp handle_block_paging_options(query, paging_options) do
    case paging_options do
      %PagingOptions{key: {_block_number, 0}, is_index_in_asc_order: false} ->
        []

      _ ->
        query
        |> page_block_transactions(paging_options)
        |> limit(^paging_options.page_size)
    end
  end

  defp handle_withdrawals_paging_options(query, nil), do: query

  defp handle_withdrawals_paging_options(query, paging_options) do
    query
    |> Withdrawal.page_withdrawals(paging_options)
    |> limit(^paging_options.page_size)
  end

  @doc """
    Dynamically joins and preloads associations in a query based on necessity.

    This function adjusts the provided Ecto query to include joins for associations. It supports
    both optional and required joins. Optional joins use the `preload` function to fetch associations
    without enforcing their presence. Required joins ensure the association exists.

    ## Parameters
    - `query`: The initial Ecto query.
    - `associations`: A single association or a tuple with nested association preloads.
    - `necessity`: Specifies if the association is `:optional` or `:required`.

    ## Returns
    - The modified query with the specified associations joined according to the defined necessity.
  """
  @spec join_association(atom() | Ecto.Query.t(), [{atom(), atom()}], :optional | :required) :: Ecto.Query.t()
  def join_association(query, [{association, nested_preload}], necessity)
      when is_atom(association) and is_atom(nested_preload) do
    case necessity do
      :optional ->
        preload(query, [{^association, ^nested_preload}])

      :required ->
        from(q in query,
          inner_join: a in assoc(q, ^association),
          as: ^association,
          left_join: b in assoc(a, ^nested_preload),
          as: ^nested_preload,
          preload: [{^association, {a, [{^nested_preload, b}]}}]
        )
    end
  end

  @spec join_association(atom() | Ecto.Query.t(), atom(), :optional | :required) :: Ecto.Query.t()
  def join_association(query, association, necessity) do
    case necessity do
      :optional ->
        preload(query, ^association)

      :required ->
        from(q in query, inner_join: a in assoc(q, ^association), as: ^association, preload: [{^association, a}])
    end
  end

  @doc """
    Applies dynamic joins to a query based on provided association necessities.

    This function iterates over a map of associations with their required join types, either
    `:optional` or `:required`, and applies the corresponding joins to the given query.

    More info is available on https://hexdocs.pm/ecto/Ecto.Query.html#preload/3

    ## Parameters
    - `query`: The base query to which associations will be joined.
    - `necessity_by_association`: A map specifying each association and its necessity
      (`:optional` or `:required`).

    ## Returns
    - The query with all specified associations joined according to their necessity.
  """
  @spec join_associations(atom() | Ecto.Query.t(), %{any() => :optional | :required}) :: Ecto.Query.t()
  def join_associations(query, necessity_by_association) when is_map(necessity_by_association) do
    Enum.reduce(necessity_by_association, query, fn {association, join}, acc_query ->
      join_association(acc_query, association, join)
    end)
  end

  def page_blocks(query, %PagingOptions{key: nil}), do: query

  def page_blocks(query, %PagingOptions{key: {block_number}}) do
    where(query, [block], block.number < ^block_number)
  end

  defp page_logs(query, %PagingOptions{key: nil}), do: query

  defp page_logs(query, %PagingOptions{key: {index}}) do
    where(query, [log], log.index > ^index)
  end

  defp page_logs(query, %PagingOptions{key: {0, log_index}}) do
    where(
      query,
      [log],
      log.block_number == 0 and log.index < ^log_index
    )
  end

  defp page_logs(query, %PagingOptions{key: {block_number, 0}}) do
    where(
      query,
      [log],
      log.block_number < ^block_number
    )
  end

  defp page_logs(query, %PagingOptions{key: {block_number, log_index}}) do
    where(
      query,
      [log],
      log.block_number < ^block_number or (log.block_number == ^block_number and log.index < ^log_index)
    )
  end

  defp page_transaction_logs(query, %PagingOptions{key: nil}), do: query

  defp page_transaction_logs(query, %PagingOptions{key: {index}}) do
    where(query, [log], log.index > ^index)
  end

  defp page_transaction_logs(query, %PagingOptions{key: {_block_number, index}}) do
    where(query, [log], log.index > ^index)
  end

  defp page_block_transactions(query, %PagingOptions{key: nil}), do: query

  defp page_block_transactions(query, %PagingOptions{key: {_block_number, index}, is_index_in_asc_order: true}) do
    where(query, [transaction], transaction.index > ^index)
  end

  defp page_block_transactions(query, %PagingOptions{key: {_block_number, index}}) do
    where(query, [transaction], transaction.index < ^index)
  end

  def page_token_balances(query, %PagingOptions{key: nil}), do: query

  def page_token_balances(query, %PagingOptions{key: {value, address_hash}}) do
    where(
      query,
      [tb],
      tb.value < ^value or (tb.value == ^value and tb.address_hash < ^address_hash)
    )
  end

  def page_current_token_balances(query, keyword) when is_list(keyword),
    do: page_current_token_balances(query, Keyword.get(keyword, :paging_options))

  def page_current_token_balances(query, %PagingOptions{key: nil}), do: query

  def page_current_token_balances(query, %PagingOptions{key: {nil, value, id}}) do
    fiat_balance = CurrentTokenBalance.fiat_value_query()

    condition =
      dynamic(
        [ctb, t],
        is_nil(^fiat_balance) and
          (ctb.value < ^value or
             (ctb.value == ^value and ctb.id < ^id))
      )

    where(
      query,
      [ctb, t],
      ^condition
    )
  end

  def page_current_token_balances(query, %PagingOptions{key: {fiat_value, value, id}}) do
    fiat_balance = CurrentTokenBalance.fiat_value_query()

    condition =
      dynamic(
        [ctb, t],
        ^fiat_balance < ^fiat_value or is_nil(^fiat_balance) or
          (^fiat_balance == ^fiat_value and
             (ctb.value < ^value or
                (ctb.value == ^value and ctb.id < ^id)))
      )

    where(
      query,
      [ctb, t],
      ^condition
    )
  end

  @doc """
  The current total number of coins minted minus verifiably burnt coins.
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
          reducer :: (entry :: Hash.Address.t(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_uncataloged_token_contract_address_hashes(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    query =
      from(
        token in Token,
        where: token.cataloged == false or is_nil(token.cataloged),
        where: is_nil(token.skip_metadata) or token.skip_metadata == false,
        select: token.contract_address_hash
      )

    query
    |> add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Fetches a `t:Token.t/0` by an address hash.

  ## Options

      * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Token.t/0` has no associated record for that association,
      then the `t:Token.t/0` will not be included in the list.
  """
  @spec token_from_address_hash(Hash.Address.t() | String.t(), [necessity_by_association_option | api?]) ::
          {:ok, Token.t()} | {:error, :not_found}
  def token_from_address_hash(hash, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query =
      from(
        t in Token,
        where: t.contract_address_hash == ^hash
      )

    query
    |> join_associations(necessity_by_association)
    |> preload(:contract_address)
    |> select_repo(options).one()
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

  @spec fetch_token_transfers_from_token_hash_and_token_id(Hash.t(), non_neg_integer(), [paging_options]) :: []
  def fetch_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options \\ []) do
    TokenTransfer.fetch_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options)
  end

  @spec count_token_transfers_from_token_hash(Hash.t()) :: non_neg_integer()
  def count_token_transfers_from_token_hash(token_address_hash) do
    TokenTransfer.count_token_transfers_from_token_hash(token_address_hash)
  end

  @spec count_token_transfers_from_token_hash_and_token_id(Hash.t(), non_neg_integer(), [api?]) :: non_neg_integer()
  def count_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options \\ []) do
    TokenTransfer.count_token_transfers_from_token_hash_and_token_id(token_address_hash, token_id, options)
  end

  @spec transaction_has_token_transfers?(Hash.t()) :: boolean()
  def transaction_has_token_transfers?(transaction_hash) do
    query = from(tt in TokenTransfer, where: tt.transaction_hash == ^transaction_hash)

    Repo.exists?(query)
  end

  @spec fetch_last_token_balances_include_unfetched([Hash.Address.t()], [api?]) :: []
  def fetch_last_token_balances_include_unfetched(address_hashes, options \\ []) do
    address_hashes
    |> CurrentTokenBalance.last_token_balances_include_unfetched()
    |> select_repo(options).all()
  end

  @spec fetch_last_token_balances(Hash.Address.t(), [api? | necessity_by_association_option]) :: []
  def fetch_last_token_balances(address_hash, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    address_hash
    |> CurrentTokenBalance.last_token_balances()
    |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
    |> join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  @spec fetch_paginated_last_token_balances(Hash.Address.t(), [paging_options]) :: []
  def fetch_paginated_last_token_balances(address_hash, options) do
    filter = Keyword.get(options, :token_type)
    options = Keyword.delete(options, :token_type)
    paging_options = Keyword.get(options, :paging_options)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    case paging_options do
      %PagingOptions{key: {nil, 0, _id}} ->
        []

      _ ->
        address_hash
        |> CurrentTokenBalance.last_token_balances(options, filter)
        |> ExplorerHelper.maybe_hide_scam_addresses(:token_contract_address_hash, options)
        |> page_current_token_balances(paging_options)
        |> join_associations(necessity_by_association)
        |> select_repo(options).all()
    end
  end

  def get_token_balance(address_hash, token_contract_address_hash, block_number, token_id \\ nil, options \\ []) do
    query = TokenBalance.fetch_token_balance(address_hash, token_contract_address_hash, block_number, token_id)

    select_repo(options).one(query)
  end

  @spec address_to_balances_by_day(Hash.Address.t(), [api?]) :: [balance_by_day]
  def address_to_balances_by_day(address_hash, options \\ []) do
    latest_block_timestamp =
      address_hash
      |> CoinBalance.last_coin_balance_timestamp()
      |> select_repo(options).one()

    address_hash
    |> CoinBalanceDaily.balances_by_day()
    |> select_repo(options).all()
    |> Enum.sort_by(fn %{date: d} -> {d.year, d.month, d.day} end)
    |> replace_last_value(latest_block_timestamp)
    |> normalize_balances_by_day(Keyword.get(options, :api?, false))
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
      |> (&if(api?,
            do: &1,
            else:
              Enum.map(&1, fn day ->
                day
                |> Map.update!(:date, fn x -> to_string(x) end)
                |> Map.update!(:value, fn x -> Wei.to(x, :ether) end)
              end)
          )).()

    today = Date.to_string(NaiveDateTime.utc_now())

    if not Enum.empty?(result) && !Enum.any?(result, fn map -> to_string(map[:date]) == today end) do
      List.flatten([result | [%{date: today, value: List.last(result)[:value]}]])
    else
      result
    end
  end

  @spec fetch_token_holders_from_token_hash(Hash.Address.t(), [paging_options | api?]) :: [TokenBalance.t()]
  def fetch_token_holders_from_token_hash(contract_address_hash, options \\ []) do
    query =
      contract_address_hash
      |> CurrentTokenBalance.token_holders_ordered_by_value(options)

    query
    |> select_repo(options).all()
  end

  @spec fetch_token_holders_from_token_hash_for_csv(Hash.Address.t(), [paging_options | api?]) :: [TokenBalance.t()]
  def fetch_token_holders_from_token_hash_for_csv(contract_address_hash, options \\ []) do
    query =
      contract_address_hash
      |> CurrentTokenBalance.token_holders_ordered_by_value_query_without_address_preload(options)

    query
    |> select_repo(options).all()
  end

  def fetch_token_holders_from_token_hash_and_token_id(contract_address_hash, token_id, options \\ []) do
    contract_address_hash
    |> CurrentTokenBalance.token_holders_1155_by_token_id(token_id, options)
    |> select_repo(options).all()
  end

  def token_id_1155_is_unique?(contract_address_hash, token_id, options \\ [])

  def token_id_1155_is_unique?(_, nil, _), do: false

  def token_id_1155_is_unique?(contract_address_hash, token_id, options) do
    result =
      contract_address_hash |> CurrentTokenBalance.token_balances_by_id_limit_2(token_id) |> select_repo(options).all()

    if length(result) == 1 do
      Decimal.compare(Enum.at(result, 0), 1) == :eq
    else
      false
    end
  end

  @spec data() :: Dataloader.Ecto.t()
  def data, do: DataloaderEcto.new(Repo)

  @doc """
    Determines token transfer type by its transaction.

    ## Parameters
    - `transaction`: The transaction which token transfer type we need to determine.

    ## Returns
    - A token transfer type which can be one of the following cases:
      :erc20 | :erc721 | :erc1155 | :erc404 | :zrc2 | :token_transfer
      The `:token_transfer` means the token transfer of unknown type.
    - `nil` if this transaction is not related to any token transfer.
  """
  @spec transaction_token_transfer_type(Transaction.t()) ::
          :erc20 | :erc721 | :erc1155 | :erc404 | :zrc2 | :token_transfer | nil
  def transaction_token_transfer_type(
        %Transaction{
          status: :ok,
          created_contract_address_hash: nil,
          input: _input,
          value: value
        } = transaction
      ) do
    zero_wei = %Wei{value: Decimal.new(0)}
    result = find_token_transfer_type(transaction)

    if is_nil(result) && not Enum.empty?(transaction.token_transfers) && value == zero_wei,
      do: :token_transfer,
      else: result
  rescue
    _ -> nil
  end

  def transaction_token_transfer_type(_), do: nil

  # Determines token transfer type by its transaction.
  #
  # ## Parameters
  # - `transaction`: The transaction which token transfer type we need to determine.
  #
  # ## Returns
  # - A token transfer type which can be one of the following cases:
  #   :erc20 | :erc721 | :erc1155 | :erc404 | :zrc2
  # - `nil` if this transaction has unknown transfer type or not related to any token transfer.
  @spec find_token_transfer_type(Transaction.t()) :: :erc20 | :erc721 | :erc1155 | :erc404 | :zrc2 | nil
  defp find_token_transfer_type(transaction) do
    zero_wei = %Wei{value: Decimal.new(0)}

    # https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/token/ERC721/ERC721.sol#L35
    case {to_string(transaction.input), transaction.value} do
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

      # check for ERC-20, ZRC-2 or for old ERC-721, ERC-1155, ERC-404 token versions
      {unquote(TokenTransfer.transfer_function_signature()) <> params, ^zero_wei} ->
        types = [:address, {:uint, 256}]

        [address, value] = decode_params(params, types)

        decimal_value = Decimal.new(value)

        find_known_token_transfer(transaction.token_transfers, address, decimal_value)

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

  # Finds token transfer type by the given list of token transfers in a transaction.
  # To filter transaction's token transfers, the `to_address_hash` and `amount` fields are used.
  #
  # ## Parameters
  # - `token_transfers`: The list of transaction's token transfers.
  # - `address`: The destination address of the transfer.
  # - `decimal_value`: The decimal amount of the transfer.
  #
  # ## Returns
  # - A token transfer type which can be one of the following cases:
  #   :erc20 | :erc721 | :erc1155 | :erc404 | :zrc2
  # - `nil` if the corresponding transaction has unknown transfer type.
  @spec find_known_token_transfer(list(), binary(), Decimal.t()) :: :erc20 | :erc721 | :erc1155 | :erc404 | :zrc2 | nil
  defp find_known_token_transfer(token_transfers, address, decimal_value) do
    token_transfer =
      Enum.find(token_transfers, fn token_transfer ->
        token_transfer.to_address_hash.bytes == address && token_transfer.amount == decimal_value
      end)

    if token_transfer do
      case token_transfer.token do
        %Token{type: "ERC-20"} -> :erc20
        %Token{type: "ERC-721"} -> :erc721
        %Token{type: "ERC-1155"} -> :erc1155
        %Token{type: "ERC-404"} -> :erc404
        %Token{type: "ZRC-2"} -> :zrc2
        _ -> nil
      end
    else
      :erc20
    end
  end

  defp decode_params(params, types) do
    params
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  @spec erc_20_token?(Token.t()) :: bool
  def erc_20_token?(token) do
    erc_20_token_type?(token.type)
  end

  defp erc_20_token_type?(type) do
    case type do
      "ERC-20" -> true
      _ -> false
    end
  end

  def boolean_to_check_result(true), do: :ok

  def boolean_to_check_result(false), do: :not_found

  @spec get_token_transfer_type(TokenTransfer.t()) ::
          :token_burning | :token_minting | :token_spawning | :token_transfer
  def get_token_transfer_type(transfer) do
    {:ok, burn_address_hash} = Chain.string_to_address_hash(SmartContract.burn_address_hash_string())

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

  @spec from_block(keyword) :: any
  def from_block(options) do
    Keyword.get(options, :from_block) || nil
  end

  @spec to_block(keyword) :: any
  def to_block(options) do
    Keyword.get(options, :to_block) || nil
  end

  def address_hash_is_smart_contract?(nil), do: false

  def address_hash_is_smart_contract?(address_hash) do
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

  def recent_transactions(options, [:pending | _]) do
    Transaction.recent_pending_transactions(options, false)
  end

  def recent_transactions(options, _) do
    Transaction.recent_collated_transactions(false, options)
  end

  def count_verified_contracts_from_cache(options \\ []) do
    VerifiedContractsCount.fetch(options)
  end

  def count_new_verified_contracts_from_cache(options \\ []) do
    NewVerifiedContractsCount.fetch(options)
  end

  def count_contracts_from_cache(options \\ []) do
    ContractsCount.fetch(options)
  end

  def count_new_contracts_from_cache(options \\ []) do
    NewContractsCount.fetch(options)
  end

  @spec flat_1155_batch_token_transfers([TokenTransfer.t()], Decimal.t() | nil) :: [TokenTransfer.t()]
  def flat_1155_batch_token_transfers(token_transfers, token_id \\ nil) when is_list(token_transfers) do
    token_transfers
    |> Enum.reduce([], fn tt, acc ->
      case tt.token_ids do
        token_ids when is_list(token_ids) and length(token_ids) > 1 ->
          transfers = flat_1155_batch_token_transfer(tt, tt.amounts, token_ids, token_id)

          transfers ++ acc

        _ ->
          [tt | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp flat_1155_batch_token_transfer(%TokenTransfer{} = tt, amounts, token_ids, token_id_to_filter) do
    amounts
    |> Enum.zip(token_ids)
    |> Enum.with_index()
    |> Enum.map(fn {{amount, token_id}, index} ->
      if is_nil(token_id_to_filter) || token_id == token_id_to_filter do
        %TokenTransfer{tt | token_ids: [token_id], amount: amount, amounts: nil, index_in_batch: index}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> squash_token_transfers_in_batch()
  end

  defp squash_token_transfers_in_batch(token_transfers) do
    token_transfers
    |> Enum.group_by(fn tt -> {List.first(tt.token_ids), tt.from_address_hash, tt.to_address_hash} end)
    |> Enum.map(fn {_k, v} -> Enum.reduce(v, nil, &group_batch_reducer/2) end)
    |> Enum.sort_by(fn tt -> tt.index_in_batch end, :asc)
  end

  defp group_batch_reducer(transfer, nil) do
    transfer
  end

  defp group_batch_reducer(transfer, %TokenTransfer{} = acc) do
    %TokenTransfer{acc | amount: Decimal.add(acc.amount, transfer.amount)}
  end

  @spec paginate_1155_batch_token_transfers([TokenTransfer.t()], [paging_options]) :: [TokenTransfer.t()]
  def paginate_1155_batch_token_transfers(token_transfers, options) do
    paging_options = options |> Keyword.get(:paging_options, nil)

    case paging_options do
      %PagingOptions{batch_key: batch_key} when not is_nil(batch_key) ->
        filter_previous_page_transfers(token_transfers, batch_key)

      _ ->
        token_transfers
    end
  end

  defp filter_previous_page_transfers(
         token_transfers,
         {batch_block_hash, batch_transaction_hash, batch_log_index, index_in_batch}
       ) do
    token_transfers
    |> Enum.reverse()
    |> Enum.reduce_while([], fn tt, acc ->
      if tt.block_hash == batch_block_hash and tt.transaction_hash == batch_transaction_hash and
           tt.log_index == batch_log_index and tt.index_in_batch == index_in_batch do
        {:halt, acc}
      else
        {:cont, [tt | acc]}
      end
    end)
  end

  def select_repo(options) do
    if Keyword.get(options, :api?, false) do
      Repo.replica()
    else
      Repo
    end
  end

  def list_withdrawals(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

        Withdrawal.list_withdrawals()
        |> join_associations(necessity_by_association)
        |> handle_withdrawals_paging_options(paging_options)
        |> select_repo(options).all()
    end
  end

  def add_fetcher_limit(query, false), do: query

  def add_fetcher_limit(query, true) do
    fetcher_limit = Application.get_env(:indexer, :fetcher_init_limit)

    limit(query, ^fetcher_limit)
  end

  @spec default_paging_options() :: map()
  def default_paging_options do
    @default_paging_options
  end
end
