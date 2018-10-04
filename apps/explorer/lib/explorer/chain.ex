defmodule Explorer.Chain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query,
    only: [
      from: 2,
      join: 4,
      limit: 2,
      order_by: 2,
      order_by: 3,
      preload: 2,
      where: 2,
      where: 3,
      select: 3
    ]

  alias Ecto.Adapters.SQL
  alias Ecto.Multi

  alias Explorer.Chain.{
    Address,
    Address.TokenBalance,
    Address.CoinBalance,
    Block,
    Data,
    Hash,
    Import,
    InternalTransaction,
    Log,
    SmartContract,
    Token,
    TokenTransfer,
    Transaction,
    Wei
  }

  alias Explorer.Chain.Block.Reward
  alias Explorer.{PagingOptions, Repo}
  alias Explorer.Counters.TokenTransferCounter

  @default_paging_options %PagingOptions{page_size: 50}

  @typedoc """
  The name of an association on the `t:Ecto.Schema.t/0`
  """
  @type association :: atom()

  @typedoc """
  Event type where data is broadcasted whenever data is inserted from chain indexing.
  """
  @type chain_event ::
          :addresses
          | :address_coin_balances
          | :blocks
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

  @doc """
  Gets an estimated count of `t:Explorer.Chain.Address.t/0`'s where the `fetched_coin_balance` is > 0
  """
  @spec address_estimated_count :: non_neg_integer()
  def address_estimated_count do
    {:ok, %Postgrex.Result{rows: result}} =
      Repo.query("""
      EXPLAIN SELECT COUNT(a0.hash) FROM addresses AS a0 WHERE (a0.fetched_coin_balance > 0)
      """)

    {[explain], _} = List.pop_at(result, 1)
    [[_ | [rows]]] = Regex.scan(~r/rows=(\d+)/, explain)
    String.to_integer(rows)
  end

  @doc """
  `t:Explorer.Chain.InternalTransaction/0`s from `address`.

  This function excludes any internal transactions in the results where the internal transaction has no siblings within
  the parent transaction.

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
  @spec address_to_internal_transactions(Address.t(), [paging_options | necessity_by_association_option]) :: [
          InternalTransaction.t()
        ]
  def address_to_internal_transactions(%Address{hash: hash}, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    direction = Keyword.get(options, :direction)
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    InternalTransaction
    |> join(
      :inner,
      [internal_transaction],
      transaction in assoc(internal_transaction, :transaction)
    )
    |> join(:left, [internal_transaction, transaction], block in assoc(transaction, :block))
    |> InternalTransaction.where_address_fields_match(hash, direction)
    |> where_transaction_has_multiple_internal_transactions()
    |> page_internal_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(
      [it, transaction, block],
      desc: block.number,
      desc: transaction.index,
      desc: it.index
    )
    |> preload(transaction: :block)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  @doc """
  Pending `t:Explorer.Chain.Transaction/0`s from `address`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.

  """
  @spec address_to_pending_transactions(Address.t(), [necessity_by_association_option]) :: [Transaction.t()]
  def address_to_pending_transactions(
        %Address{hash: %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash},
        options \\ []
      )
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    options
    |> Keyword.get(:direction)
    |> case do
      :from -> [:from_address_hash]
      :to -> [:to_address_hash]
      _ -> [:from_address_hash, :to_address_hash]
    end
    |> Enum.map(fn address_field ->
      Transaction
      |> Transaction.where_address_fields_match(address_hash, address_field)
      |> join_associations(necessity_by_association)
      |> where([transaction], is_nil(transaction.block_number))
      |> order_by([transaction], desc: transaction.inserted_at, desc: transaction.hash)
      |> Repo.all()
      |> MapSet.new()
    end)
    |> Enum.reduce(MapSet.new(), &MapSet.union/2)
    |> MapSet.to_list()
  end

  @doc """
  Gets an estimated count of `t:Explorer.Chain.Transaction.t/0` to or from the `address` based on the estimated rows
  resulting in an EXPLAIN of the query plan for the count query.
  """
  @spec address_to_transactions_estimated_count(Address.t()) :: non_neg_integer()
  def address_to_transactions_estimated_count(%Address{hash: address_hash}) do
    {:ok, %Postgrex.Result{rows: result}} =
      Repo.query(
        """
        EXPLAIN SELECT COUNT(DISTINCT t.hash) FROM
        (
          SELECT t0.hash FROM transactions AS t0 WHERE t0.from_address_hash = $1
          UNION
          SELECT t0.hash FROM transactions AS t0 WHERE t0.to_address_hash = $1
          UNION
          SELECT t0.hash FROM transactions AS t0 WHERE t0.created_contract_address_hash = $1
          UNION
          SELECT tt.transaction_hash AS hash FROM token_transfers AS tt
          WHERE tt.from_address_hash = $1
          UNION
          SELECT tt.transaction_hash AS hash FROM token_transfers AS tt
          WHERE tt.to_address_hash = $1
        ) as t
        """,
        [address_hash.bytes]
      )

    {[unique_explain], _} = List.pop_at(result, 1)
    [[_ | [rows]]] = Regex.scan(~r/rows=(\d+)/, unique_explain)
    String.to_integer(rows)
  end

  @doc """
  `t:Explorer.Chain.Transaction/0`s from `address`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, index}`) and. Results will be the transactions older than
      the `block_number` and `index` that are passed.

  """
  @spec address_to_transactions(Address.t(), [paging_options | necessity_by_association_option]) :: [Transaction.t()]
  def address_to_transactions(
        %Address{hash: %Hash{byte_count: unquote(Hash.Address.byte_count())} = address_hash},
        options \\ []
      )
      when is_list(options) do
    direction = Keyword.get(options, :direction)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    transaction_matches =
      direction
      |> case do
        :from -> [:from_address_hash]
        :to -> [:to_address_hash, :created_contract_address_hash]
        _ -> [:from_address_hash, :to_address_hash, :created_contract_address_hash]
      end
      |> Enum.map(fn address_field ->
        paging_options
        |> fetch_transactions()
        |> Transaction.where_address_fields_match(address_hash, address_field)
        |> join_associations(necessity_by_association)
        |> Transaction.preload_token_transfers(address_hash)
        |> Repo.all()
        |> MapSet.new()
      end)

    token_transfer_matches =
      paging_options
      |> fetch_transactions()
      |> TokenTransfer.where_address_fields_match(address_hash, direction)
      |> join_associations(necessity_by_association)
      |> Transaction.preload_token_transfers(address_hash)
      |> Repo.all()
      |> MapSet.new()

    transaction_matches
    |> Enum.reduce(token_transfer_matches, &MapSet.union/2)
    |> MapSet.to_list()
    |> Enum.sort_by(& &1.index, &>=/2)
    |> Enum.sort_by(& &1.block_number, &>=/2)
    |> Enum.slice(0..paging_options.page_size)
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
  The average time it took to mine/validate the last <= 100 `t:Explorer.Chain.Block.t/0`
  """
  @spec average_block_time :: %Timex.Duration{}
  def average_block_time do
    {:ok, %Postgrex.Result{rows: [[rows]]}} =
      SQL.query(
        Repo,
        """
          SELECT coalesce(avg(difference), interval '0 seconds')
          FROM (
            SELECT b.timestamp - lag(b.timestamp) over (order by b.timestamp) as difference
            FROM (SELECT * FROM blocks ORDER BY number DESC LIMIT 101) b
            LIMIT 100 OFFSET 1
          ) t
        """,
        []
      )

    {:ok, value} = Timex.Ecto.Time.load(rows)

    value
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

  @doc !"""
       Returns a default value if no value is found.
       """
  defmacrop default_if_empty(value, default) do
    quote do
      fragment("coalesce(?, ?)", unquote(value), unquote(default))
    end
  end

  @doc !"""
       Sum of the products of two columns.
       """
  defmacrop sum_of_products(col_a, col_b) do
    quote do
      sum(fragment("?*?", unquote(col_a), unquote(col_b)))
    end
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
  @spec block_reward(Block.t()) :: Wei.t()
  def block_reward(%Block{number: block_number}) do
    query =
      from(
        block in Block,
        left_join: transaction in assoc(block, :transactions),
        inner_join: block_reward in Reward,
        on: fragment("? <@ ?", block.number, block_reward.block_range),
        where: block.number == ^block_number,
        group_by: block_reward.reward,
        select: %{
          transaction_reward: %Wei{
            value: default_if_empty(sum_of_products(transaction.gas_used, transaction.gas_price), 0)
          },
          static_reward: block_reward.reward
        }
      )

    %{
      transaction_reward: transaction_reward,
      static_reward: static_reward
    } = Repo.one(query)

    Wei.sum(transaction_reward, static_reward)
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
  @spec block_to_transactions(Block.t(), [paging_options | necessity_by_association_option]) :: [Transaction.t()]
  def block_to_transactions(%Block{hash: block_hash}, options \\ []) when is_list(options) do
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
  @spec block_to_transaction_count(Block.t()) :: non_neg_integer()
  def block_to_transaction_count(%Block{hash: block_hash}) do
    query =
      from(
        transaction in Transaction,
        where: transaction.block_hash == ^block_hash
      )

    Repo.aggregate(query, :count, :hash)
  end

  @doc """
  How many blocks have confirmed `block` based on the current `max_block_number`
  """
  @spec confirmations(Block.t(), [{:max_block_number, Block.block_number()}]) :: non_neg_integer()
  def confirmations(%Block{number: number}, named_arguments) when is_list(named_arguments) do
    max_block_number = Keyword.fetch!(named_arguments, :max_block_number)

    max_block_number - number
  end

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

  """
  @spec hash_to_address(Hash.Address.t()) :: {:ok, Address.t()} | {:error, :not_found}
  def hash_to_address(%Hash{byte_count: unquote(Hash.Address.byte_count())} = hash) do
    query =
      from(
        address in Address,
        preload: [:contracts_creation_internal_transaction, :names, :smart_contract, :token],
        where: address.hash == ^hash
      )

    query
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      address -> {:ok, address}
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

  def find_contract_address(%Hash{byte_count: unquote(Hash.Address.byte_count())} = hash) do
    query =
      from(
        address in Address,
        preload: [:contracts_creation_internal_transaction, :names, :smart_contract, :token],
        where: address.hash == ^hash and not is_nil(address.contract_code)
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

    fetch_transactions()
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
  The number of `t:Explorer.Chain.InternalTransaction.t/0`.

      iex> transaction =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block()
      iex> insert(:internal_transaction, index: 0, transaction: transaction)
      iex> Explorer.Chain.internal_transaction_count()
      1

  If there are none, the count is `0`.

      iex> Explorer.Chain.internal_transaction_count()
      0

  """
  def internal_transaction_count do
    Repo.aggregate(InternalTransaction, :count, :id)
  end

  @doc """
  Finds block with greatest number.

      iex> insert(:block, number: 2)
      iex> insert(:block, number: 1)
      iex> {:ok, %Explorer.Chain.Block{number: number}} = Explorer.Chain.max_numbered_block()
      iex> number
      2

  If there are no blocks `{:error, :not_found}` is returned.

      iex> Explorer.Chain.max_numbered_block()
      {:error, :not_found}

  """
  @spec max_numbered_block() :: {:ok, Block.t()} | {:error, :not_found}
  def max_numbered_block do
    query = from(block in Block, order_by: [desc: block.number], limit: 1)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
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
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    block_type = Keyword.get(options, :block_type, "Block")

    Block
    |> Block.block_type_filter(block_type)
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  @doc """
  Lists the top 250 `t:Explorer.Chain.Address.t/0`'s' in descending order based on coin balance.

  """
  @spec list_top_addresses :: [Address.t()]
  def list_top_addresses do
    Address
    |> limit(250)
    |> order_by(desc: :fetched_coin_balance, asc: :hash)
    |> where([address], address.fetched_coin_balance > ^0)
    |> Repo.all()
  end

  @doc """
  Finds all Blocks validated by the address given.

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
          Address.t()
        ) :: [Block.t()]
  def get_blocks_validated_by_address(options \\ [], %Address{hash: hash}) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    Block
    |> join_associations(necessity_by_association)
    |> where(miner_hash: ^hash)
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> Repo.all()
  end

  @doc """
  Counts the number of `t:Explorer.Chain.Block.t/0` validated by the `address`.
  """
  @spec address_to_validation_count(Address.t()) :: non_neg_integer()
  def address_to_validation_count(%Address{hash: hash}) do
    Block
    |> where(miner_hash: ^hash)
    |> select([b], count(b.hash))
    |> Repo.one()
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
    Repo.transaction(
      fn ->
        query =
          from(
            balance in CoinBalance,
            where: is_nil(balance.value_fetched_at),
            select: %{address_hash: balance.address_hash, block_number: balance.block_number}
          )

        query
        |> Repo.stream(timeout: :infinity)
        |> Enum.reduce(initial, reducer)
      end,
      timeout: :infinity
    )
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
    Repo.transaction(
      fn ->
        query = TokenBalance.unfetched_token_balances()

        query
        |> Repo.stream(timeout: :infinity)
        |> Enum.reduce(initial, reducer)
      end,
      timeout: :infinity
    )
  end

  @doc """
  Returns a stream of all collated transactions with unfetched internal transactions.

  Only transactions that have been collated into a block are returned; pending transactions not in a block are filtered
  out.

      iex> pending = insert(:transaction)
      iex> unfetched_collated =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block()
      iex> fetched_collated =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block(internal_transactions_indexed_at: DateTime.utc_now())
      iex> {:ok, hash_set} = Explorer.Chain.stream_transactions_with_unfetched_internal_transactions(
      ...>   [:hash],
      ...>   MapSet.new(),
      ...>   fn %Explorer.Chain.Transaction{hash: hash}, acc ->
      ...>     MapSet.put(acc, hash)
      ...>   end
      ...> )
      iex> pending.hash in hash_set
      false
      iex> unfetched_collated.hash in hash_set
      true
      iex> fetched_collated.hash in hash_set
      false

  """
  @spec stream_transactions_with_unfetched_internal_transactions(
          fields :: [
            :block_hash
            | :internal_transactions_indexed_at
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
  def stream_transactions_with_unfetched_internal_transactions(fields, initial, reducer) when is_function(reducer, 2) do
    Repo.transaction(
      fn ->
        query =
          from(
            t in Transaction,
            # exclude pending transactions
            where: not is_nil(t.block_hash) and is_nil(t.internal_transactions_indexed_at),
            select: ^fields
          )

        query
        |> Repo.stream(timeout: :infinity)
        |> Enum.reduce(initial, reducer)
      end,
      timeout: :infinity
    )
  end

  @doc """
  Returns a stream of all `t:Explorer.Chain.Block.t/0` `hash`es that are marked as unfetched in
  `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`.

  When a block is fetched, its uncles are transformed into `t:Explorer.Chain.Block.SecondDegreeRelation.t/0` and can be
  returned.  Once the uncle is imported its corresponding `t:Explorer.Chain.Block.SecondDegreeRelation.t/0`
  `uncle_fetched_at` will be set and it won't be returned anymore.
  """
  @spec stream_unfetched_uncle_hashes(
          initial :: accumulator,
          reducer :: (entry :: Hash.Full.t(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_uncle_hashes(initial, reducer) when is_function(reducer, 2) do
    Repo.transaction(
      fn ->
        query =
          from(bsdr in Block.SecondDegreeRelation,
            where: is_nil(bsdr.uncle_fetched_at),
            select: bsdr.uncle_hash,
            group_by: bsdr.uncle_hash
          )

        query
        |> Repo.stream(timeout: :infinity)
        |> Enum.reduce(initial, reducer)
      end,
      timeout: :infinity
    )
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
    Repo.aggregate(Log, :count, :id)
  end

  @doc """
  The maximum `t:Explorer.Chain.Block.t/0` `number`

  If blocks are skipped and inserted out of number order, the max number is still returned

      iex> insert(:block, number: 2)
      iex> insert(:block, number: 1)
      iex> Explorer.Chain.max_block_number()
      {:ok, 2}

  If there are no blocks, `{:error, :not_found}` is returned

      iex> Explorer.Chain.max_block_number()
      {:error, :not_found}

  """
  @spec max_block_number() :: {:ok, Block.block_number()} | {:error, :not_found}
  def max_block_number do
    case Repo.aggregate(Block, :max, :number) do
      nil -> {:error, :not_found}
      number -> {:ok, number}
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

  """
  @spec missing_block_number_ranges(Range.t()) :: [Range.t()]
  def missing_block_number_ranges(range)

  def missing_block_number_ranges(range_start..range_end) do
    {step, first, last, direction} =
      if range_start <= range_end do
        {1, :minimum, :maximum, :asc}
      else
        {-1, :maximum, :minimum, :desc}
      end

    query =
      from(
        b in Block,
        right_join:
          missing_block_number_range in fragment(
            # adapted from https://www.xaprb.com/blog/2006/03/22/find-contiguous-ranges-with-sql/
            """
            WITH missing_blocks AS
                 (SELECT number
                  FROM generate_series(? :: bigint, ? :: bigint, ? :: bigint) AS number
                  EXCEPT
                  SELECT blocks.number
                  FROM blocks
                  WHERE blocks.consensus = true)
            SELECT no_previous.number AS minimum,
                   (SELECT MIN(no_next.number)
                    FROM missing_blocks AS no_next
                    LEFT OUTER JOIN missing_blocks AS next
                    ON no_next.number = next.number - 1
                    WHERE next.number IS NULL AND
                          no_next.number >= no_previous.number) AS maximum
            FROM missing_blocks as no_previous
            LEFT OUTER JOIN missing_blocks AS previous
            ON previous.number = no_previous.number - 1
            WHERE previous.number IS NULL
            """,
            ^range_start,
            ^range_end,
            ^step
          ),
        select: %Range{
          first: field(missing_block_number_range, ^first),
          last: field(missing_block_number_range, ^last)
        },
        order_by: [{^direction, field(missing_block_number_range, ^first)}],
        # needed because the join makes a cartesian product with all block rows, but we need to use Block to make
        # Ecto work.
        distinct: true
      )

    Repo.all(query, timeout: :infinity)
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
    |> where([transaction], is_nil(transaction.block_hash))
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
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{block_number, index}`) and. Results will be the transactions older than
      the `block_number` and `index` that are passed.

  """
  @spec recent_collated_transactions([paging_options | necessity_by_association_option]) :: [Transaction.t()]
  def recent_collated_transactions(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions()
    |> where([transaction], not is_nil(transaction.block_number) and not is_nil(transaction.index))
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
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
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.
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
    |> where([transaction], is_nil(transaction.block_hash))
    |> order_by([transaction], desc: transaction.inserted_at, desc: transaction.hash)
    |> join_associations(necessity_by_association)
    |> preload([{:token_transfers, [:token, :from_address, :to_address]}])
    |> Repo.all()
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
  Subscribes the caller process to a specified subset of chain-related events.

  ## Handling An Event

  A subscribed process should handle an event message. The message is in the
  format of a three-element tuple.

  * Element 0 - `:chain_event`
  * Element 1 - event subscribed to
  * Element 2 - event data in list form

  # A new block event in a GenServer
  def handle_info({:chain_event, :blocks, blocks}, state) do
  # Do something with the blocks
  end

  ## Example

  iex> Explorer.Chain.subscribe_to_events(:blocks)
  :ok
  """
  @spec subscribe_to_events(chain_event()) :: :ok
  def subscribe_to_events(event_type)
      when event_type in ~w(addresses address_coin_balances blocks exchange_rate internal_transactions logs token_transfers transactions)a do
    Registry.register(Registry.ChainEvents, event_type, [])
    :ok
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Transaction.t/0`.

  Estimated count of both collated and pending transactions using the transactions table statistics.
  """
  @spec transaction_estimated_count() :: non_neg_integer()
  def transaction_estimated_count do
    %Postgrex.Result{rows: [[rows]]} =
      SQL.query!(Repo, "SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname='transactions'")

    rows
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

  @spec transaction_to_internal_transactions(Transaction.t(), [paging_options | necessity_by_association_option]) :: [
          InternalTransaction.t()
        ]
  def transaction_to_internal_transactions(
        %Transaction{hash: %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash},
        options \\ []
      )
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    InternalTransaction
    |> for_parent_transaction(hash)
    |> join_associations(necessity_by_association)
    |> where_transaction_has_multiple_internal_transactions()
    |> page_internal_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by([internal_transaction], asc: internal_transaction.index)
    |> preload(transaction: :block)
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
  @spec transaction_to_logs(Transaction.t(), [paging_options | necessity_by_association_option]) :: [Log.t()]
  def transaction_to_logs(
        %Transaction{hash: %Hash{byte_count: unquote(Hash.Full.byte_count())} = transaction_hash},
        options \\ []
      )
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    Log
    |> join(:inner, [log], transaction in assoc(log, :transaction))
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
  @spec transaction_to_token_transfers(Transaction.t(), [paging_options | necessity_by_association_option]) :: [
          TokenTransfer.t()
        ]
  def transaction_to_token_transfers(
        %Transaction{hash: %Hash{byte_count: unquote(Hash.Full.byte_count())} = transaction_hash},
        options \\ []
      )
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    TokenTransfer
    |> join(:inner, [token_transfer], transaction in assoc(token_transfer, :transaction))
    |> where([_, transaction], transaction.hash == ^transaction_hash)
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
  def transaction_to_status(%Transaction{block_hash: nil, status: nil}), do: :pending
  def transaction_to_status(%Transaction{status: nil}), do: :awaiting_internal_transactions
  def transaction_to_status(%Transaction{status: :ok}), do: :success

  def transaction_to_status(%Transaction{status: :error, internal_transactions_indexed_at: nil, error: nil}),
    do: {:error, :awaiting_internal_transactions}

  def transaction_to_status(%Transaction{status: :error, error: error}) when is_binary(error), do: {:error, error}

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

  @doc """
  Inserts a `t:SmartContract.t/0`.

  As part of inserting a new smart contract, an additional record is inserted for
  naming the address for reference.
  """
  @spec create_smart_contract(map()) :: {:ok, SmartContract.t()} | {:error, Ecto.Changeset.t()}
  def create_smart_contract(attrs \\ %{}) do
    smart_contract_changeset = SmartContract.changeset(%SmartContract{}, attrs)

    insert_result =
      Multi.new()
      |> Multi.insert(:smart_contract, smart_contract_changeset)
      |> Multi.run(:clear_primary_address_names, &clear_primary_address_names/1)
      |> Multi.run(:insert_address_name, &create_address_name/1)
      |> Repo.transaction()

    with {:ok, %{smart_contract: smart_contract}} <- insert_result do
      {:ok, smart_contract}
    else
      {:error, :smart_contract, changeset, _} ->
        {:error, changeset}
    end
  end

  defp clear_primary_address_names(%{smart_contract: %SmartContract{address_hash: address_hash}}) do
    clear_primary_query =
      from(
        address_name in Address.Name,
        where: address_name.address_hash == ^address_hash,
        update: [set: [primary: false]]
      )

    Repo.update_all(clear_primary_query, [])

    {:ok, []}
  end

  defp create_address_name(%{smart_contract: %SmartContract{name: name, address_hash: address_hash}}) do
    params = %{
      address_hash: address_hash,
      name: name,
      primary: true
    }

    %Address.Name{}
    |> Address.Name.changeset(params)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:address_hash, :name])
  end

  @spec address_hash_to_smart_contract(%Explorer.Chain.Hash{}) :: %Explorer.Chain.SmartContract{} | nil
  def address_hash_to_smart_contract(%Explorer.Chain.Hash{} = address_hash) do
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

  defp page_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_blocks(query, %PagingOptions{key: {block_number}}) do
    where(query, [block], block.number < ^block_number)
  end

  defp page_internal_transaction(query, %PagingOptions{key: nil}), do: query

  defp page_internal_transaction(query, %PagingOptions{key: {block_number, transaction_index, index}}) do
    where(
      query,
      [internal_transaction, transaction],
      transaction.block_number < ^block_number or
        (transaction.block_number == ^block_number and transaction.index < ^transaction_index) or
        (transaction.block_number == ^block_number and transaction.index == ^transaction_index and
           internal_transaction.index < ^index)
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
    * includes internal transactions of type create, reward, or suicide
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
          (SELECT COUNT(sibling.id)
          FROM internal_transactions AS sibling
          WHERE sibling.transaction_hash = ?)
          """,
          transaction.hash
        ) > 1
    )
  end

  @doc """
  The current total number of coins minted minus verifiably burned coins.
  """
  @spec total_supply :: non_neg_integer()
  def total_supply do
    supply_module().total()
  end

  @doc """
  The current number coins in the market for trading.
  """
  @spec circulating_supply :: non_neg_integer()
  def circulating_supply do
    supply_module().circulating()
  end

  defp supply_module do
    Application.get_env(:explorer, :supply, Explorer.Chain.Supply.ProofOfAuthority)
  end

  @doc """
  Streams a lists token contract addresses that haven't been cataloged.
  """
  @spec stream_uncataloged_token_contract_address_hashes(
          initial :: accumulator,
          reducer :: (entry :: Hash.Address.t(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_uncataloged_token_contract_address_hashes(initial_acc, reducer) when is_function(reducer, 2) do
    Repo.transaction(
      fn ->
        query =
          from(
            token in Token,
            where: token.cataloged == false,
            select: token.contract_address_hash
          )

        query
        |> Repo.stream(timeout: :infinity)
        |> Enum.reduce(initial_acc, reducer)
      end,
      timeout: :infinity
    )
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
        where: is_nil(tf.id),
        select: t.block_number,
        distinct: t.block_number
      )

    Repo.transaction(
      fn ->
        query
        |> Repo.stream(timeout: :infinity)
        |> Enum.reduce([], &[&1 | &2])
      end,
      timeout: :infinity
    )
  end

  @doc """
  Fetches a `t:Token.t/0` by an address hash.
  """
  @spec token_from_address_hash(Hash.Address.t()) :: {:ok, Token.t()} | {:error, :not_found}
  def token_from_address_hash(%Hash{byte_count: unquote(Hash.Address.byte_count())} = hash) do
    query =
      from(
        token in Token,
        where: token.contract_address_hash == ^hash,
        preload: [{:contract_address, :smart_contract}]
      )

    case Repo.one(query) do
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

  @spec count_token_transfers_from_token_hash(Hash.t()) :: non_neg_integer()
  def count_token_transfers_from_token_hash(token_address_hash) do
    TokenTransferCounter.fetch(token_address_hash)
  end

  @spec transaction_has_token_transfers?(Hash.t()) :: boolean()
  def transaction_has_token_transfers?(transaction_hash) do
    query = from(tt in TokenTransfer, where: tt.transaction_hash == ^transaction_hash, limit: 1, select: 1)

    Repo.one(query) != nil
  end

  @spec address_tokens_with_balance(Hash.Address.t(), [any()]) :: []
  def address_tokens_with_balance(address_hash, paging_options \\ []) do
    address_hash
    |> Address.Token.list_address_tokens_with_balance(paging_options)
    |> Repo.all()
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

    token_opts = [on_conflict: :replace_all, conflict_target: :contract_address_hash]
    address_name_opts = [on_conflict: :nothing, conflict_target: [:address_hash, :name]]

    insert_result =
      Multi.new()
      |> Multi.insert(:token, token_changeset, token_opts)
      |> Multi.run(
        :address_name,
        fn _ ->
          {:ok, Repo.insert(address_name_changeset, address_name_opts)}
        end
      )
      |> Repo.transaction()

    with {:ok, %{token: token}} <- insert_result do
      {:ok, token}
    else
      {:error, :token, changeset, _} ->
        {:error, changeset}
    end
  end

  @spec fetch_last_token_balances(Hash.Address.t()) :: []
  def fetch_last_token_balances(address_hash) do
    address_hash
    |> TokenBalance.last_token_balances()
    |> Repo.all()
  end

  @spec fetch_token_holders_from_token_hash(Hash.Address.t(), [paging_options]) :: [TokenBalance.t()]
  def fetch_token_holders_from_token_hash(contract_address_hash, options) do
    contract_address_hash
    |> TokenBalance.token_holders_ordered_by_value(options)
    |> Repo.all()
  end

  # This function is deprecated.
  #
  # The code is being treated at https://github.com/poanetwork/blockscout/issues/880
  @spec count_token_holders_from_token_hash(Hash.Address.t()) :: non_neg_integer()
  def count_token_holders_from_token_hash(contract_address_hash) do
    contract_address_hash
    |> TokenBalance.token_holders_from_token_hash()
    |> Repo.aggregate(:count, :address_hash)
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
end
