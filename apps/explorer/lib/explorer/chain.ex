defmodule Explorer.Chain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query, only: [from: 2, or_where: 3, order_by: 2, preload: 2, where: 2]

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Address, Block, Hash, InternalTransaction, Log, Receipt, Transaction, Wei}
  alias Explorer.Repo

  # Types

  @typedoc """
  The name of an association on the `t:Ecto.Schema.t/0`
  """
  @type association :: atom()

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

  @typedoc """
  Pagination params used by `scrivener`
  """
  @type pagination :: map()

  @typep after_hash_option :: {:after_hash, Hash.t()}
  @typep direction_option :: {:direction, direction}
  @typep inserted_after_option :: {:inserted_after, DateTime.t()}
  @typep necessity_by_association_option :: {:necessity_by_association, necessity_by_association}
  @typep pagination_option :: {:pagination, pagination}
  @typep timestamps :: %{inserted_at: DateTime.t(), updated_at: DateTime.t()}
  @typep timestamps_option :: {:timestamps, timestamps}

  # Functions
  @doc """
  `t:Explorer.Chain.Transaction/0`s from `address`.

  ## Options

  * `:direction` - if specified, will filter transactions by address type. If `:to` is specified, only transactions
      where the "to" address matches will be returned. Likewise, if `:from` is specified, only transactions where the
      "from" address matches will be returned. If :direction is omitted, transactions either to or from the address
      will be returned.
  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
  * `:pagination` - pagination params to pass to scrivener.

  """
  @spec address_to_transactions(Address.t(), [
          direction_option | necessity_by_association_option | pagination_option
        ]) :: %Scrivener.Page{entries: [Transaction.t()]}
  def address_to_transactions(%Address{hash: hash}, options \\ []) when is_list(options) do
    address_hash_to_transactions(hash, options)
  end

  @doc """
  The `t:Explorer.Chain.Address.t/0` `balance` in `unit`.
  """
  @spec balance(Address.t(), :wei) :: Wei.t() | nil
  @spec balance(Address.t(), :gwei) :: Wei.gwei() | nil
  @spec balance(Address.t(), :ether) :: Wei.ether() | nil
  def balance(%Address{fetched_balance: balance}, unit) do
    case balance do
      nil -> nil
      _ -> Wei.to(balance, unit)
    end
  end

  @spec update_balances(
          %{address_hash :: String.t => balance :: integer}
        ) :: :ok | {:error, reason :: term}
  def update_balances(balances) do
    timestamps = timestamps()
    changes =
      for {hash_string, amount} <- balances do
        {:ok, truncated_hash} = Explorer.Chain.Hash.Truncated.cast(hash_string)
        Map.merge(timestamps, %{
          hash: truncated_hash,
          fetched_balance: amount,
          balance_fetched_at: timestamps.updated_at,
        })
      end

    {_, _} = Repo.safe_insert_all(Address, changes,
      conflict_target: :hash, on_conflict: :replace_all)
    :ok
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
  Finds all `t:Explorer.Chain.Transaction.t/0` in the `t:Explorer.Chain.Block.t/0`.

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
  * `:pagination` - pagination params to pass to scrivener.
  """
  @spec block_to_transactions(Block.t()) :: %Scrivener.Page{entries: [Transaction.t()]}
  @spec block_to_transactions(Block.t(), [necessity_by_association_option | pagination_option]) :: %Scrivener.Page{
          entries: [Transaction.t()]
        }
  def block_to_transactions(%Block{hash: block_hash}, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    pagination = Keyword.get(options, :pagination, %{})

    query =
      from(
        transaction in Transaction,
        inner_join: block in assoc(transaction, :block),
        where: block.hash == ^block_hash,
        order_by: [desc: transaction.inserted_at, desc: transaction.hash]
      )

    query
    |> join_associations(necessity_by_association)
    |> Repo.paginate(pagination)
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

  A `String.t/0` value for `Explorer.Chain.Addres.t/0` `hash` must have 40 hexadecimal characters after the `0x` prefix
  to prevent short- and long-hash transcription errors.

      iex> {:error, %Ecto.Changeset{errors: errors}} = Explorer.Chain.create_address(
      ...>   %{hash: "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0"}
      ...> )
      ...> errors
      [hash: {"is invalid", [type: Explorer.Chain.Hash.Truncated, validation: :cast]}]
      iex> {:error, %Ecto.Changeset{errors: errors}} = Explorer.Chain.create_address(
      ...>   %{hash: "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0ba"}
      ...> )
      ...> errors
      [hash: {"is invalid", [type: Explorer.Chain.Hash.Truncated, validation: :cast]}]

  """
  @spec create_address(map()) :: {:ok, Address.t()} | {:error, Ecto.Changeset.t()}
  def create_address(attrs \\ %{}) do
    %Address{}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  The fee a `transaction` paid for the `t:Explorer.Transaction.t/0` `gas`

  If the transaction is pending, then the fee will be a range of `unit`

      iex> Explorer.Chain.fee(
      ...>   %Explorer.Chain.Transaction{gas: Decimal.new(3), gas_price: Decimal.new(2), receipt: nil},
      ...>   :wei
      ...> )
      {:maximum, Decimal.new(6)}

  If the transaction has been confirmed in block, then the fee will be the actual fee paid in `unit` for the `gas_used`
  in the `receipt`.

      iex> Explorer.Chain.fee(
      ...>   %Explorer.Chain.Transaction{
      ...>     gas: Decimal.new(3),
      ...>     gas_price: Decimal.new(2),
      ...>     receipt: %Explorer.Chain.Receipt{gas_used: Decimal.new(2)}
      ...>   },
      ...>   :wei
      ...> )
      {:actual, Decimal.new(4)}

  """
  @spec fee(%Transaction{receipt: nil}, :ether | :gwei | :wei) :: {:maximum, Decimal.t()}
  def fee(%Transaction{gas: gas, gas_price: gas_price, receipt: nil}, unit) do
    fee =
      gas
      |> Decimal.mult(gas_price)
      |> Wei.to(unit)

    {:maximum, fee}
  end

  @spec fee(%Transaction{receipt: Receipt.t()}, :ether | :gwei | :wei) :: {:actual, Decimal.t()}
  def fee(%Transaction{gas_price: gas_price, receipt: %Receipt{gas_used: gas_used}}, unit) do
    fee =
      gas_used
      |> Decimal.mult(gas_price)
      |> Wei.to(unit)

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
  @spec hash_to_address(Hash.Truncated.t()) :: {:ok, Address.t()} | {:error, :not_found}
  def hash_to_address(%Hash{byte_count: unquote(Hash.Truncated.byte_count())} = hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^hash,
        preload: [:credit, :debit]
      )

    query
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      address -> {:ok, address}
    end
  end

  @doc """
  Converts the `t:t/0` to string representation shown to users.

      iex> Explorer.Chain.hash_to_iodata(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b ::
      ...>              big-integer-size(32)-unit(8)>>
      ...>   }
      ...> )
      [
        "0x",
        ['9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b']
      ]

  Always pads number, so that it is a valid format for casting.

      iex> Explorer.Chain.hash_to_iodata(
      ...>   %Explorer.Chain.Hash{
      ...>     byte_count: 32,
      ...>     bytes: <<0x1234567890abcdef :: big-integer-size(32)-unit(8)>>
      ...>   }
      ...> )
      [
        "0x",
        [
          [
            [
              [
                [['000', 48, 48, 48], '000', 48, 48, 48],
                ['000', 48, 48, 48],
                '000',
                48,
                48,
                48
              ],
              [['000', 48, 48, 48], '000', 48, 48, 48],
              ['000', 48, 48, 48],
              '000',
              48,
              48,
              48
            ],
            49,
            50,
            51,
            52,
            53,
            54,
            55,
            56,
            57,
            48,
            97,
            98,
            99,
            100,
            101,
            102
          ]
        ]
      ]

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
  def hash_to_transaction(%Hash{byte_count: unquote(Hash.Full.byte_count())} = hash, options \\ [])
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Transaction
    |> where(hash: ^hash)
    |> join_associations(necessity_by_association)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      transaction -> {:ok, transaction}
    end
  end

  @doc """
  Bulk insert blocks from a list of blocks.

  ## Tree

  * `t:Explorer.Chain.Block.t/0`s
    * `t:Explorer.Chain.Transaction.t/0`
      * `t.Explorer.Chain.InternalTransaction.t/0`
      * `t.Explorer.Chain.Receipt.t/0`
        * `t.Explorer.Chain.Log.t/0`

  """
  def import_blocks(%{
        blocks_params: blocks_params,
        logs_params: logs_params,
        internal_transactions_params: internal_transactions_params,
        receipts_params: receipts_params,
        transactions_params: transactions_params
      })
      when is_list(blocks_params) and is_list(internal_transactions_params) and is_list(logs_params) and
             is_list(receipts_params) and is_list(transactions_params) do
    with {:ok, ecto_schema_module_to_changes_list} <-
           ecto_schema_module_to_params_list_to_ecto_schema_module_to_changes_list(%{
             Block => blocks_params,
             Log => logs_params,
             InternalTransaction => internal_transactions_params,
             Receipt => receipts_params,
             Transaction => transactions_params
           }) do
      insert_ecto_schema_module_to_changes_list(ecto_schema_module_to_changes_list)
    end
  end

  @doc """
  The number of `t:Explorer.Chain.Address.t/0`.
  """
  def address_count do
    Repo.aggregate(Address, :count, :hash)
  end

  @doc """
  The number of `t:Explorer.Chain.InternalTransaction.t/0`.

      iex> insert(:internal_transaction, index: 0)
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
  * `:pagination` - pagination params to pass to scrivener.

  """
  @spec list_blocks([necessity_by_association_option | pagination_option]) :: %Scrivener.Page{
          entries: [Block.t()]
        }
  def list_blocks(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    pagination = Keyword.get(options, :pagination, %{})

    Block
    |> join_associations(necessity_by_association)
    |> order_by(desc: :number)
    |> Repo.paginate(pagination)
  end

  @doc """
  Returns a stream of unfetched `Explorer.Chain.Address.t/0`.
  """
  def stream_unfetched_addresses(initial, reducer) when is_function(reducer) do
    Repo.transaction(fn ->
      from(a in Address, where: is_nil(a.balance_fetched_at))
      |> Repo.stream()
      |> Enum.reduce(initial, reducer)
    end)
  end

  @doc """
  The number of `t:Explorer.Chain.Log.t/0`.

      iex> block = insert(:block)
      iex> transaction = insert(:transaction, block_hash: block.hash, index: 0)
      iex> receipt = insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)
      iex> insert(:log, transaction_hash: receipt.transaction_hash, index: 0)
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
  TODO
  """
  def missing_block_numbers do
    {:ok, {_, missing_count, missing_ranges}} =
      Repo.transaction(fn ->
        query = from(b in Block, select: b.number, order_by: [asc: b.number])

        query
        |> Repo.stream(max_rows: 1000)
        |> Enum.reduce({-1, 0, []}, fn
          num, {prev, missing_count, acc} when prev + 1 == num ->
            {num, missing_count, acc}

          num, {prev, missing_count, acc} ->
            {num, missing_count + (num - prev - 1), [{prev + 1, num - 1} | acc]}
        end)
      end)

    {missing_count, missing_ranges}
  end

  @doc """
  Finds `t:Explorer.Chain.Block.t/0` with `number`

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
    |> where(number: ^number)
    |> join_associations(necessity_by_association)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  @doc """
  The number of `t:Explorer.Chain.Receipt.t/0`.

      iex> block = insert(:block)
      iex> transaction = insert(:transaction, block_hash: block.hash, index: 0)
      iex> insert(:receipt, transaction_hash: transaction.hash, transaction_index: transaction.index)
      iex> Explorer.Chain.receipt_count()
      1

  When there are no `t:Explorer.Chain.Receipt.t/0`.

      iex> Explorer.Chain.receipt_count()
      0

  """
  def receipt_count do
    Repo.aggregate(Receipt, :count, :transaction_hash)
  end

  @doc """
  Returns the list of collated transactions that occurred recently (10).

      iex> 2 |> insert_list(:transaction) |> validate()
      iex> insert(:transaction) # unvalidated transaction
      iex> 8 |> insert_list(:transaction) |> validate()
      iex> recent_collated_transactions = Explorer.Chain.recent_collated_transactions()
      iex> length(recent_collated_transactions)
      10
      iex> Enum.all?(recent_collated_transactions, fn %Explorer.Chain.Transaction{block_hash: block_hash} ->
      ...>   !is_nil(block_hash)
      ...> end)
      true

  A `t:Explorer.Chain.Transaction.t/0` `hash` can be supplied to the `:after_hash` option, then only transactions in
  after the transaction (with a greater index) in the same block or in a later block (with a greater number) will be
  returned.  This can be used to generate paging for collated transaction.

      iex> first_block = insert(:block, number: 1)
      iex> first_transaction_in_first_block = insert(:transaction, block_hash: first_block.hash, index: 0)
      iex> second_transaction_in_first_block = insert(:transaction, block_hash: first_block.hash, index: 1)
      iex> second_block = insert(:block, number: 2)
      iex> first_transaction_in_second_block = insert(:transaction, block_hash: second_block.hash, index: 0)
      iex> after_first_transaciton_in_first_block = Explorer.Chain.recent_collated_transactions(
      ...>   after_hash: first_transaction_in_first_block.hash
      ...> )
      iex> length(after_first_transaciton_in_first_block)
      2
      iex> after_second_transaciton_in_first_block = Explorer.Chain.recent_collated_transactions(
      ...>   after_hash: second_transaction_in_first_block.hash
      ...> )
      iex> length(after_second_transaciton_in_first_block)
      1
      iex> after_first_transaciton_in_second_block = Explorer.Chain.recent_collated_transactions(
      ...>   after_hash: first_transaction_in_second_block.hash
      ...> )
      iex> length(after_first_transaciton_in_second_block)
      0

  When there are no collated transactions, an empty list is returned.

     iex> insert(:transaction)
     iex> Explorer.Chain.recent_collated_transactions()
     []

  Using an unvalidated transaction's hash for `:after_hash` will also yield an empty list.

     iex> %Explorer.Chain.Transaction{hash: hash} = insert(:transaction)
     iex> insert(:transaction)
     iex> Explorer.Chain.recent_collated_transactions(after_hash: hash)
     []

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.

  """
  @spec recent_collated_transactions([after_hash_option | necessity_by_association_option]) :: [Transaction.t()]
  def recent_collated_transactions(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query =
      from(
        transaction in Transaction,
        inner_join: block in assoc(transaction, :block),
        order_by: [desc: block.number, desc: transaction.index],
        limit: 10
      )

    query
    |> after_hash(options)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  @doc """
  Return the list of pending transactions that occurred recently (10).

      iex> 2 |> insert_list(:transaction)
      iex> :transaction |> insert() |> validate()
      iex> 8 |> insert_list(:transaction)
      iex> recent_pending_transactions = Explorer.Chain.recent_pending_transactions()
      iex> length(recent_pending_transactions)
      10
      iex> Enum.all?(recent_pending_transactions, fn %Explorer.Chain.Transaction{block_hash: block_hash} ->
      ...>   is_nil(block_hash)
      ...> end)
      true

  A `t:Explorer.Chain.Transaction.t/0` `inserted_at` can be supplied to the `:inserted_after` option, then only pending
  transactions inserted after that transaction will be returned.  This can be used to generate paging for pending
  transactions.

      iex> {:ok, first_inserted_at, 0} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      iex> insert(:transaction, inserted_at: first_inserted_at)
      iex> {:ok, second_inserted_at, 0} = DateTime.from_iso8601("2016-01-23T23:50:07Z")
      iex> insert(:transaction, inserted_at: second_inserted_at)
      iex> after_first_transaction = Explorer.Chain.recent_pending_transactions(inserted_after: first_inserted_at)
      iex> length(after_first_transaction)
      1
      iex> after_second_transaction = Explorer.Chain.recent_pending_transactions(inserted_after: second_inserted_at)
      iex> length(after_second_transaction)
      0

  When there are no pending transaction and a collated transaction's inserted_at is used, an empty list is returned

      iex> {:ok, first_inserted_at, 0} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      iex> :transaction |> insert(inserted_at: first_inserted_at) |> validate()
      iex> {:ok, second_inserted_at, 0} = DateTime.from_iso8601("2016-01-23T23:50:07Z")
      iex> :transaction |> insert(inserted_at: second_inserted_at) |> validate()
      iex> Explorer.Chain.recent_pending_transactions(after_inserted_at: first_inserted_at)
      []

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.

  """
  @spec recent_pending_transactions([inserted_after_option | necessity_by_association_option]) :: [Transaction.t()]
  def recent_pending_transactions(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query =
      from(
        transaction in Transaction,
        where: is_nil(transaction.block_hash),
        order_by: [
          desc: transaction.inserted_at,
          # arbitary tie-breaker when inserted at is the same.  hash is random distribution, but using it keeps order
          # consistent at least
          desc: transaction.hash
        ],
        limit: 10
      )

    query
    |> inserted_after(options)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  @doc """
  The `string` must start with `0x`, then is converted to an integer and then to `t:Explorer.Chain.Hash.Truncated.t/0`.

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
  @spec string_to_address_hash(String.t()) :: {:ok, Hash.Truncated.t()} | :error
  def string_to_address_hash(string) when is_binary(string) do
    Hash.Truncated.cast(string)
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
  `t:Explorer.Chain.Transaction/0`s to `address`.

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
  * `:pagination` - pagination params to pass to scrivener.

  """
  @spec to_address_to_transactions(Address.t(), [
          necessity_by_association_option | pagination_option
        ]) :: %Scrivener.Page{entries: [Transaction.t()]}
  def to_address_to_transactions(address = %Address{}, options \\ []) when is_list(options) do
    address_to_transactions(address, Keyword.put(options, :direction, :to))
  end

  @doc """
  Count of `t:Explorer.Chain.Transaction.t/0`.

  With no options or an explicit `pending: nil`, both collated and pending transactions will be counted.

      iex> insert(:transaction)
      iex> :transaction |> insert() |> validate()
      iex> Explorer.Chain.transaction_count()
      2
      iex> Explorer.Chain.transaction_count(pending: nil)
      2

  To count only collated transactions, pass `pending: false`.

      iex> 2 |> insert_list(:transaction)
      iex> 3 |> insert_list(:transaction) |> validate()
      iex> Explorer.Chain.transaction_count(pending: false)
      3

  To count only pending transactions, pass `pending: true`.

      iex> 2 |> insert_list(:transaction)
      iex> 3 |> insert_list(:transaction) |> validate()
      iex> Explorer.Chain.transaction_count(pending: true)
      2

  ## Options

  * `:pending`
    * `nil` - count all transactions
    * `true` - only count pending transactions
    * `false` - only count collated transactions

  """
  @spec transaction_count([{:pending, boolean()}]) :: non_neg_integer()
  def transaction_count(options \\ []) when is_list(options) do
    Transaction
    |> where_pending(options)
    |> Repo.aggregate(:count, :hash)
  end

  @doc """
  `t:Explorer.Chain.InternalTransaction/0`s in `t:Explorer.Chain.Transaction.t/0` with `hash`.

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.

  """
  @spec transaction_hash_to_internal_transactions(Hash.Full.t()) :: [InternalTransaction.t()]
  def transaction_hash_to_internal_transactions(
        %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash,
        options \\ []
      )
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    InternalTransaction
    |> for_parent_transaction(hash)
    |> join_associations(necessity_by_association)
    |> Repo.all()
  end

  @doc """
  Finds all `t:Explorer.Chain.Log.t/0`s for `t:Explorer.Chain.Transaction.t/0`.

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Log.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Log.t/0` will not be included in the page `entries`.
  * `:pagination` - pagination params to pass to scrivener.

  """
  @spec transaction_to_logs(Transaction.t(), [
          necessity_by_association_option | pagination_option
        ]) :: %Scrivener.Page{entries: [Log.t()]}
  def transaction_to_logs(%Transaction{hash: hash}, options \\ []) when is_list(options) do
    transaction_hash_to_logs(hash, options)
  end

  @doc """
  Converts `transaction` with its `receipt` loaded to the status of the `t:Explorer.Chain.Transaction.t/0`.

  ## Returns

  * `:failed` - the transaction failed without running out of gas
  * `:pending` - the transaction has not be confirmed in a block yet
  * `:out_of_gas` - the transaction failed because it ran out of gas
  * `:success` - the transaction has been confirmed in a block

  """
  @spec transaction_to_status(Transaction.t()) :: :failed | :pending | :out_of_gas | :success
  def transaction_to_status(%Transaction{receipt: nil}), do: :pending
  def transaction_to_status(%Transaction{receipt: %Receipt{status: :ok}}), do: :success

  def transaction_to_status(%Transaction{
        gas: gas,
        receipt: %Receipt{gas_used: gas_used, status: :error}
      })
      when gas_used >= gas do
    :out_of_gas
  end

  def transaction_to_status(%Transaction{receipt: %Receipt{status: :error}}), do: :failed

  @doc """
  The `t:Explorer.Chain.Transaction.t/0` or `t:Explorer.Chain.InternalTransaction.t/0` `value` of the `transaction` in
  `unit`.
  """
  @spec value(InternalTransaction.t(), :wei) :: Wei.t()
  @spec value(InternalTransaction.t(), :gwei) :: Wei.gwei()
  @spec value(InternalTransaction.t(), :ether) :: Wei.ether()
  @spec value(Transaction.t(), :wei) :: Wei.t()
  @spec value(Transaction.t(), :gwei) :: Wei.gwei()
  @spec value(Transaction.t(), :ether) :: Wei.ether()
  def value(%type{value: value}, unit) when type in [InternalTransaction, Transaction] do
    Wei.to(value, unit)
  end

  ## Private Functions

  defp address_hash_to_transactions(
         %Hash{byte_count: unquote(Hash.Truncated.byte_count())} = address_hash,
         named_arguments
       )
       when is_list(named_arguments) do
    address_fields =
      case Keyword.get(named_arguments, :direction) do
        :to -> [:to_address_hash]
        :from -> [:from_address_hash]
        nil -> [:from_address_hash, :to_address_hash]
      end

    necessity_by_association = Keyword.get(named_arguments, :necessity_by_association, %{})
    pagination = Keyword.get(named_arguments, :pagination, %{})

    Transaction
    |> join_associations(necessity_by_association)
    |> reverse_chronologically()
    |> where_address_fields_match(address_fields, address_hash)
    |> Repo.paginate(pagination)
  end

  defp after_hash(query, options) do
    case Keyword.fetch(options, :after_hash) do
      {:ok, hash} ->
        from(
          transaction in query,
          inner_join: block in assoc(transaction, :block),
          join: hash_transaction in Transaction,
          on: hash_transaction.hash == ^hash,
          inner_join: hash_block in assoc(hash_transaction, :block),
          where:
            block.number > hash_block.number or
              (block.number == hash_block.number and transaction.index > hash_transaction.index)
        )

      :error ->
        query
    end
  end

  @spec changes_list(params :: map, [{:for, module}]) :: {:ok, changes :: map} | {:error, [Changeset.t()]}
  defp changes_list(params, named_arguments) when is_list(named_arguments) do
    ecto_schema_module = Keyword.fetch!(named_arguments, :for)
    struct = ecto_schema_module.__struct__()

    {status, acc} =
      params
      |> Stream.map(&ecto_schema_module.changeset(struct, &1))
      |> Enum.reduce({:ok, []}, fn
        changeset = %Changeset{valid?: false}, {:ok, _} -> {:error, [changeset]}
        changeset = %Changeset{valid?: false}, {:error, acc_changesets} -> {:error, [changeset | acc_changesets]}
        %Changeset{changes: changes, valid?: true}, {:ok, acc_changes} -> {:ok, [changes | acc_changes]}
        %Changeset{valid?: true}, {:error, _} = error -> error
      end)

    {status, Enum.reverse(acc)}
  end

  defp ecto_schema_module_changes_list_to_address_hash_set({ecto_schema_module, changes_list}) do
    Enum.reduce(changes_list, MapSet.new(), fn changes, acc ->
      changes
      |> ecto_schema_module.changes_to_address_hash_set()
      |> MapSet.union(acc)
    end)
  end

  defp ecto_schema_module_to_changes_list_to_address_hash_set(ecto_schema_module_to_changes_list) do
    Enum.reduce(ecto_schema_module_to_changes_list, MapSet.new(), fn ecto_schema_module_changes_list, acc ->
      ecto_schema_module_changes_list
      |> ecto_schema_module_changes_list_to_address_hash_set()
      |> MapSet.union(acc)
    end)
  end

  defp ecto_schema_module_to_params_list_to_ecto_schema_module_to_changes_list(ecto_schema_module_to_params_list) do
    ecto_schema_module_to_params_list
    |> Stream.map(fn {ecto_schema_module, params} ->
      {ecto_schema_module, changes_list(params, for: ecto_schema_module)}
    end)
    |> Enum.reduce({:ok, %{}}, fn
      {ecto_schema_module, {:ok, changes_list}}, {:ok, ecto_schema_module_to_changes_list} ->
        {:ok, Map.put(ecto_schema_module_to_changes_list, ecto_schema_module, changes_list)}

      {_, {:ok, _}}, {:error, _} = error ->
        error

      {_, {:error, _} = error}, {:ok, _} ->
        error

      {_, {:error, changesets}}, {:error, acc_changesets} ->
        {:error, acc_changesets ++ changesets}
    end)
  end

  defp for_parent_transaction(query, %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash) do
    from(
      child in query,
      inner_join: transaction in assoc(child, :transaction),
      where: transaction.hash == ^hash
    )
  end

  @spec insert_addresses([map()], [timestamps_option]) :: {:ok, Block.t()} | {:error, [Changeset.t()]}
  defp insert_addresses(changes_list, named_arguments) when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)

    insert_changes_list(
      changes_list,
      conflict_target: :hash,
      on_conflict: [set: [balance_fetched_at: nil]],
      for: Address,
      timestamps: timestamps
    )
    {:ok, for(changes <- changes_list, do: changes.hash)}
  end

  @spec insert_blocks([map()], [timestamps_option]) :: {:ok, Block.t()} | {:error, [Changeset.t()]}
  defp insert_blocks(changes_list, named_arguments) when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)

    insert_changes_list(
      changes_list,
      conflict_target: :number,
      on_conflict: :replace_all,
      for: Block,
      timestamps: timestamps
    )
  end

  defp insert_ecto_schema_module_to_changes_list(
         %{
           Block => blocks_changes,
           Log => logs_changes,
           InternalTransaction => internal_transactions_changes,
           Receipt => receipts_changes,
           Transaction => transactions_changes
         } = ecto_schema_module_to_changes_list
       ) do
    address_hash_set = ecto_schema_module_to_changes_list_to_address_hash_set(ecto_schema_module_to_changes_list)
    addresses_changes = Address.hash_set_to_changes_list(address_hash_set)

    timestamps = timestamps()

    Multi.new()
    |> Multi.run(:addresses, fn _ -> insert_addresses(addresses_changes, timestamps: timestamps) end)
    |> Multi.run(:blocks, fn _ -> insert_blocks(blocks_changes, timestamps: timestamps) end)
    |> Multi.run(:transactions, fn _ -> insert_transactions(transactions_changes, timestamps: timestamps) end)
    |> Multi.run(:internal_transactions, fn _ ->
      insert_internal_transactions(internal_transactions_changes, timestamps: timestamps)
    end)
    |> Multi.run(:receipts, fn _ -> insert_receipts(receipts_changes, timestamps: timestamps) end)
    |> Multi.run(:logs, fn _ -> insert_logs(logs_changes, timestamps: timestamps) end)
    |> Repo.transaction()
  end

  @spec insert_internal_transactions([map()], [timestamps_option]) ::
          {:ok, InternalTransaction.t()} | {:error, [Changeset.t()]}
  defp insert_internal_transactions(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)

    insert_changes_list(
      changes_list,
      for: InternalTransaction,
      timestamps: timestamps
    )
  end

  @spec insert_logs([map()], [timestamps_option]) :: {:ok, Log.t()} | {:error, [Changeset.t()]}
  defp insert_logs(changes_list, named_arguments) when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)

    insert_changes_list(
      changes_list,
      conflict_target: [:transaction_hash, :index],
      on_conflict: :replace_all,
      for: Log,
      timestamps: timestamps
    )
  end

  @spec insert_receipts([map()], [timestamps_option]) :: {:ok, Receipt.t()} | {:error, [Changeset.t()]}
  defp insert_receipts(changes_list, named_arguments) when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)

    insert_changes_list(
      changes_list,
      conflict_target: :transaction_hash,
      on_conflict: :replace_all,
      for: Receipt,
      timestamps: timestamps
    )
  end

  defp insert_changes_list(changes_list, options) when is_list(changes_list) do
    ecto_schema_module = Keyword.fetch!(options, :for)

    timestamped_changes_list = timestamp_changes_list(changes_list, Keyword.fetch!(options, :timestamps))
    {_, inserted} = Repo.safe_insert_all(ecto_schema_module, timestamped_changes_list, Keyword.delete(options, :for))
    {:ok, inserted}
  end

  @spec insert_transactions([map()], [timestamps_option]) :: {:ok, Transaction.t()} | {:error, [Changeset.t()]}
  defp insert_transactions(changes_list, named_arguments) when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)

    insert_changes_list(
      changes_list,
      conflict_target: :hash,
      on_conflict: :replace_all,
      for: Transaction,
      timestamps: timestamps
    )
  end

  defp inserted_after(query, options) do
    case Keyword.fetch(options, :inserted_after) do
      {:ok, inserted_after} ->
        from(transaction in query, where: ^inserted_after < transaction.inserted_at)

      :error ->
        query
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

  defp reverse_chronologically(query) do
    from(q in query, order_by: [desc: q.inserted_at, desc: q.hash])
  end

  defp timestamp_params(changes, timestamps) when is_map(changes) do
    Map.merge(changes, timestamps)
  end

  defp timestamp_changes_list(changes_list, timestamps) when is_list(changes_list) do
    Enum.map(changes_list, &timestamp_params(&1, timestamps))
  end

  defp timestamps do
    now = Ecto.DateTime.utc()
    %{inserted_at: now, updated_at: now}
  end

  defp transaction_hash_to_logs(%Hash{byte_count: unquote(Hash.Full.byte_count())} = transaction_hash, options)
       when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    pagination = Keyword.get(options, :pagination, %{})

    query =
      from(
        log in Log,
        join: transaction in assoc(log, :transaction),
        where: transaction.hash == ^transaction_hash,
        order_by: [asc: :index]
      )

    query
    |> join_associations(necessity_by_association)
    |> Repo.paginate(pagination)
  end

  defp where_address_fields_match(query, address_fields, address_hash) do
    Enum.reduce(address_fields, query, fn field, query ->
      or_where(query, [t], field(t, ^field) == ^address_hash)
    end)
  end

  defp where_pending(query, options) when is_list(options) do
    pending = Keyword.get(options, :pending)

    case pending do
      false ->
        from(transaction in query, where: not is_nil(transaction.block_hash))

      true ->
        from(transaction in query, where: is_nil(transaction.block_hash))

      nil ->
        query
    end
  end
end
