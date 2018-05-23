defmodule Explorer.Chain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query, only: [from: 2, join: 4, or_where: 3, order_by: 2, order_by: 3, preload: 2, where: 2, where: 3]

  alias Ecto.{Changeset, Multi}

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    Hash,
    InternalTransaction,
    Log,
    Transaction,
    Wei,
    SmartContract,
    Data
  }

  alias Explorer.Chain.Block.Reward
  alias Explorer.Repo

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
  @typep params_option :: {:params, map()}
  @typep timeout_option :: {:timeout, timeout}
  @typep timestamps :: %{inserted_at: DateTime.t(), updated_at: DateTime.t()}
  @typep timestamps_option :: {:timestamps, timestamps}
  @typep addresses_option :: {:adddresses, [params_option | timeout_option]}
  @typep blocks_option :: {:blocks, [params_option | timeout_option]}
  @typep internal_transactions_option :: {:internal_transactions, [params_option | timeout_option]}
  @typep logs_option :: {:logs, [params_option | timeout_option]}
  @typep receipts_option :: {:receipts, [params_option | timeout_option]}
  @typep transactions_option :: {:transactions, [params_option | timeout_option]}

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
    * `:pagination` - pagination params to pass to scrivener.

  """
  def address_to_internal_transactions(%Address{hash: hash}, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    direction = Keyword.get(options, :direction)
    pagination = Keyword.get(options, :pagination, %{})

    InternalTransaction
    |> join(
      :inner,
      [internal_transaction],
      transaction in assoc(internal_transaction, :transaction)
    )
    |> join(:left, [internal_transaction, transaction], block in assoc(transaction, :block))
    |> where_address_fields_match(hash, direction)
    |> where_transaction_has_multiple_internal_transactions()
    |> order_by(
      [it, transaction, block],
      desc: block.number,
      desc: transaction.index,
      desc: it.index
    )
    |> preload(transaction: :block)
    |> join_associations(necessity_by_association)
    |> Repo.paginate(pagination)
  end

  @doc """
  Counts the number of `t:Explorer.Chain.Transaction.t/0` to or from the `address`.
  """
  @spec address_to_transaction_count(Address.t()) :: non_neg_integer()
  def address_to_transaction_count(%Address{hash: hash}) do
    Transaction
    |> where_address_fields_match(hash)
    |> Repo.aggregate(:count, :hash)
  end

  @doc """
  `t:Explorer.Chain.Transaction/0`s from `address`.

  ## Options

    * `:direction` - if specified, will filter transactions by address type. If `:to` is specified, only transactions
      where the "to" address matches will be returned. Likewise, if `:from` is specified, only transactions where the
      "from" address matches will be returned. If `:direction` is omitted, transactions either to or from the address
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
  @spec balance(Address.t(), :wei) :: Wei.wei() | nil
  @spec balance(Address.t(), :gwei) :: Wei.gwei() | nil
  @spec balance(Address.t(), :ether) :: Wei.ether() | nil
  def balance(%Address{fetched_balance: balance}, unit) do
    case balance do
      nil -> nil
      _ -> Wei.to(balance, unit)
    end
  end

  # timeouts all in milliseconds

  @transaction_timeout 120_000
  @insert_addresses_timeout 60_000
  @insert_blocks_timeout 60_000
  @insert_internal_transactions_timeout 60_000
  @insert_logs_timeout 60_000
  @insert_transactions_timeout 60_000
  @update_transactions_timeout 60_000

  @doc """
  Updates `t:Explorer.Chain.Address.t/0` with `hash` of `address_hash` to have `fetched_balance` of `balance` in
  `t:map/0` `balances` of `address_hash` to `balance`.

      iex> Explorer.Chain.update_balances(%{"0x8bf38d4764929064f2d4d3a56520a76ab3df415b" => 100})
      :ok
      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x8bf38d4764929064f2d4d3a56520a76ab3df415b")
      iex> {:ok, address} = Explorer.Chain.hash_to_address(hash)
      iex> address.fetched_balance
      %Explorer.Chain.Wei{value: Decimal.new(100)}

  There don't need to be any updates.

      iex> Explorer.Chain.update_balances(%{})
      :ok

  ## Options

   * `:addresses`
      * `:timeout` - the timeout for upserting all addresses with the updated balances.  Defaults to
        `#{@insert_addresses_timeout}`.
   * `:timeout` - the timeout for the whole `c:Ecto.Repo.transaction/0` call.  Defaults to `#{@transaction_timeout}`
      milliseconds.

  """
  @spec update_balances(%{(address_hash :: String.t()) => balance :: integer}, [
          [{:addresses, [timeout_option]}] | timeout_option
        ]) :: :ok
  def update_balances(balances, options \\ []) when is_list(options) do
    timestamps = timestamps()

    changes_list =
      for {hash_string, amount} <- balances do
        {:ok, truncated_hash} = Explorer.Chain.Hash.Truncated.cast(hash_string)
        {:ok, wei} = Wei.cast(amount)

        Map.merge(timestamps, %{
          hash: truncated_hash,
          fetched_balance: wei,
          balance_fetched_at: timestamps.updated_at
        })
      end

    # order so that row ShareLocks are grabbed in a consistent order.
    # MUST match order used in `insert_addresses/2`
    ordered_changes_list = sort_address_changes_list(changes_list)

    Repo.transaction(
      fn ->
        {_, _} =
          Repo.safe_insert_all(
            Address,
            ordered_changes_list,
            conflict_target: :hash,
            on_conflict: :replace_all,
            timeout: options[:addresses][:timeout] || @insert_addresses_timeout
          )
      end,
      timeout: options[:timeout] || @transaction_timeout
    )

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
  Converts the `Explorer.Chain.Data.t:t/0` to `iodata` representation that can be written to users effciently.

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
  @spec hash_to_address(Hash.Truncated.t()) :: {:ok, Address.t()} | {:error, :not_found}
  def hash_to_address(%Hash{byte_count: unquote(Hash.Truncated.byte_count())} = hash) do
    query =
      from(
        address in Address,
        where: address.hash == ^hash
      )

    query
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      address -> {:ok, address}
    end
  end

  def find_contract_address(%Hash{byte_count: unquote(Hash.Truncated.byte_count())} = hash) do
    address =
      Repo.one(
        from(
          address in Address,
          where: address.hash == ^hash and not is_nil(address.contract_code)
        )
      )

    if address do
      {:ok, address}
    else
      {:error, :not_found}
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
      nil -> {:error, :not_found}
      transaction -> {:ok, transaction}
    end
  end

  @doc """
  Bulk insert blocks from a list of blocks.

  The import returns the unique key(s) for each type of record inserted.

  | Key                      | Value Type                                                                 | Value Description                                                                             |
  |--------------------------|----------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
  | `:addresses`             | `[Explorer.Chain.Hash.t()]`                                                | List of `t:Explorer.Chain.Address.t/0` `hash`                                                 |
  | `:blocks`                | `[Explorer.Chain.Hash.t()]`                                                | List of `t:Explorer.Chain.Block.t/0` `hash`                                                   |
  | `:internal_transactions` | `[%{index: non_neg_integer(), transaction_hash: Explorer.Chain.Hash.t()}]` | List of maps of the `t:Explorer.Chain.InternalTransaction.t/0` `index` and `transaction_hash` |
  | `:logs`                  | `[%{index: non_neg_integer(), transaction_hash: Explorer.Chain.Hash.t()}]` | List of maps of the `t:Explorer.Chain.Log.t/0` `index` and `transaction_hash`                 |
  | `:transactions`          | `[Explorer.Chain.Hash.t()]`                                                | List of `t:Explorer.Chain.Transaction.t/0` `hash`                                             |

      iex> Explorer.Chain.import_blocks(
      ...>   blocks: [
      ...>     params: [
      ...>       %{
      ...>         difficulty: 340282366920938463463374607431768211454,
      ...>         gas_limit: 6946336,
      ...>         gas_used: 50450,
      ...>         hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         nonce: 0,
      ...>         number: 37,
      ...>         parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
      ...>         size: 719,
      ...>         timestamp: Timex.parse!("2017-12-15T21:06:30Z", "{ISO:Extended:Z}"),
      ...>         total_difficulty: 12590447576074723148144860474975121280509
      ...>       }
      ...>     ],
      ...>   ],
      ...>   internal_transactions: [
      ...>     params: [
      ...>       %{
      ...>         call_type: "call",
      ...>         from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         gas: 4677320,
      ...>         gas_used: 27770,
      ...>         index: 0,
      ...>         output: "0x",
      ...>         to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         trace_address: [],
      ...>         transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         type: "call",
      ...>         value: 0
      ...>       }
      ...>     ],
      ...>   ],
      ...>   logs: [
      ...>     params: [
      ...>       %{
      ...>         address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
      ...>         fourth_topic: nil,
      ...>         index: 0,
      ...>         second_topic: nil,
      ...>         third_topic: nil,
      ...>         transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         type: "mined"
      ...>       }
      ...>     ],
      ...>   ],
      ...>   transactions: [
      ...>     params: [
      ...>       %{
      ...>         block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         block_number: 37,
      ...>         cumulative_gas_used: 50450,
      ...>         from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         gas: 4700000,
      ...>         gas_price: 100000000000,
      ...>         gas_used: 50450,
      ...>         hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         index: 0,
      ...>         input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         nonce: 4,
      ...>         public_key: "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
      ...>         r: 0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01,
      ...>         s: 0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f,
      ...>         standard_v: 1,
      ...>         status: :ok,
      ...>         to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         v: 0xbe,
      ...>         value: 0
      ...>       }
      ...>     ]
      ...>   ],
      ...>   addresses: [
      ...>     params: [
      ...>        %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
      ...>        %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"}
      ...>     ]
      ...>   ]
      ...> )
      {:ok,
       %{
         addresses: [
           %Explorer.Chain.Hash{
             byte_count: 20,
             bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211,
               165, 101, 32, 167, 106, 179, 223, 65, 91>>
           },
           %Explorer.Chain.Hash{
             byte_count: 20,
             bytes: <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121,
               132, 89, 192, 16, 79, 223, 94, 152, 122, 202>>
           }
         ],
         blocks: [
           %Explorer.Chain.Hash{
             byte_count: 32,
             bytes: <<246, 180, 184, 200, 141, 243, 235, 210, 82, 236, 71,
               99, 40, 51, 77, 192, 38, 207, 102, 96, 106, 132, 251, 118,
               155, 61, 60, 188, 204, 132, 113, 189>>
           }
         ],
         internal_transactions: [
           %{
             index: 0,
             transaction_hash: %Explorer.Chain.Hash{
               byte_count: 32,
               bytes: <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136,
                 27, 174, 236, 38, 46, 123, 149, 35, 77, 57, 101, 36, 140,
                 57, 254, 153, 47, 255, 212, 51, 229>>
             }
           }
         ],
         logs: [
           %{
             index: 0,
             transaction_hash: %Explorer.Chain.Hash{
               byte_count: 32,
               bytes: <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136,
                 27, 174, 236, 38, 46, 123, 149, 35, 77, 57, 101, 36, 140,
                 57, 254, 153, 47, 255, 212, 51, 229>>
             }
           }
         ],
         transactions: [
           %Explorer.Chain.Hash{
             byte_count: 32,
             bytes: <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136,
               27, 174, 236, 38, 46, 123, 149, 35, 77, 57, 101, 36, 140,
               57, 254, 153, 47, 255, 212, 51, 229>>
           }
         ]
       }}

  A completely empty tree can be imported, but options must still be supplied.  It is a non-zero amount of time to
  process the empty options, so if there is nothing to import, you should avoid calling
  `Explorer.Chain.import_blocks/1`.  If you don't supply any options with params, then nothing is run so there result is
  an empty map.

      iex> Explorer.Chain.import_blocks([])
      {:ok, %{}}

  The params for each key are validated using the corresponding `Ecto.Schema` module's `changeset/2` function.  If there
  are errors, they are returned in `Ecto.Changeset.t`s, so that the original, invalid value can be reconstructed for any
  error messages.

      iex> {:error, [internal_transaction_changeset, transaction_changeset]} = Explorer.Chain.import_blocks(
      ...>   blocks: [
      ...>     params: [
      ...>       %{
      ...>         difficulty: 340282366920938463463374607431768211454,
      ...>         gas_limit: 6946336,
      ...>         gas_used: 50450,
      ...>         hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         nonce: 0,
      ...>         number: 37,
      ...>         parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
      ...>         size: 719,
      ...>         timestamp: Timex.parse!("2017-12-15T21:06:30Z", "{ISO:Extended:Z}"),
      ...>         total_difficulty: 12590447576074723148144860474975121280509
      ...>       }
      ...>     ]
      ...>   ],
      ...>   internal_transactions: [
      ...>     params: [
      ...>       %{
      ...>         from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         gas: 4677320,
      ...>         gas_used: 27770,
      ...>         index: 0,
      ...>         output: "0x",
      ...>         to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         trace_address: [],
      ...>         transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         type: "call",
      ...>         value: 0
      ...>       },
      ...>       # valid after invalid
      ...>       %{
      ...>         created_contract_address_hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>         created_contract_code: "0x606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>         from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         gas: 4597044,
      ...>         gas_used: 166651,
      ...>         index: 0,
      ...>         init: "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>         trace_address: [],
      ...>         transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         type: "create",
      ...>         value: 0
      ...>       }
      ...>     ]
      ...>   ],
      ...>   logs: [
      ...>     params: [
      ...>       %{
      ...>         address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
      ...>         fourth_topic: nil,
      ...>         index: 0,
      ...>         second_topic: nil,
      ...>         third_topic: nil,
      ...>         transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         type: "mined"
      ...>       }
      ...>     ]
      ...>   ],
      ...>   transactions: [
      ...>     params: [
      ...>       %{
      ...>         block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         block_number: 37,
      ...>         cumulative_gas_used: 50450,
      ...>         from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         gas: 4700000,
      ...>         gas_price: 100000000000,
      ...>         gas_used: 50450,
      ...>         hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         index: 0,
      ...>         input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         nonce: 4,
      ...>         public_key: "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
      ...>         r: 0xa7f8f45cce375bb7af8750416e1b03e0473f93c256da2285d1134fc97a700e01,
      ...>         s: 0x1f87a076f13824f4be8963e3dffd7300dae64d5f23c9a062af0c6ead347c135f,
      ...>         standard_v: 1,
      ...>         to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         v: 0xbe,
      ...>         value: 0
      ...>       }
      ...>     ]
      ...>   ],
      ...>   addresses: [
      ...>     params: [
      ...>       %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
      ...>       %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"},
      ...>       %{hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4"}
      ...>     ]
      ...>   ]
      ...> )
      iex> internal_transaction_changeset.errors
      [call_type: {"can't be blank", [validation: :required]}]
      iex> transaction_changeset.errors
      [
        status: {"can't be blank when the transaction is collated into a block", []}
      ]

  ## Tree

    * `t:Explorer.Chain.Block.t/0`s
      * `t:Explorer.Chain.Transaction.t/0`
        * `t.Explorer.Chain.InternalTransaction.t/0`
        * `t.Explorer.Chain.Log.t/0`

  ## Options

    * `:addresses`
      * `:params` - `list` of params for `Explorer.Chain.Address.changeset/2`.
      * `:timeout` - the timeout for inserting all addresses.  Defaults to `#{@insert_addresses_timeout}` milliseconds.
    * `:blocks`
      * `:params` - `list` of params for `Explorer.Chain.Block.changeset/2`.
      * `:timeout` - the timeout for inserting all blocks. Defaults to `#{@insert_blocks_timeout}` milliseconds.
    * `:internal_transactions`
      * `:params` - `list` of params for `Explorer.Chain.InternalTransaction.changeset/2`.
      * `:timeout` - the timeout for inserting all internal transactions. Defaults to
        `#{@insert_internal_transactions_timeout}` milliseconds.
    * `:logs`
      * `:params` - `list` of params for `Explorer.Chain.Log.changeset/2`.
      * `:timeout` - the timeout for inserting all logs. Defaults to `#{@insert_logs_timeout}` milliseconds.
    * `:timeout` - the timeout for the whole `c:Ecto.Repo.transaction/0` call.  Defaults to `#{@transaction_timeout}`
      milliseconds.
    * `:transactions`
      * `:params` - `list` of params for `Explorer.Chain.Transaction.changeset/2`.
      * `:timeout` - the timeout for inserting all transactions found in the params lists across all
        types. Defaults to `#{@insert_transactions_timeout}` milliseconds.
  """
  @spec import_blocks([
          addresses_option
          | blocks_option
          | internal_transactions_option
          | logs_option
          | receipts_option
          | timeout_option
          | transactions_option
        ]) ::
          {:ok,
           %{
             optional(:addresses) => [Hash.Truncated.t()],
             optional(:blocks) => [Hash.Full.t()],
             optional(:internal_transactions) => [
               %{required(:index) => non_neg_integer(), required(:transaction_hash) => Hash.Full.t()}
             ],
             optional(:logs) => [
               %{required(:index) => non_neg_integer(), required(:transaction_hash) => Hash.Full.t()}
             ],
             optional(:receipts) => [Hash.Full.t()],
             optional(:transactions) => [Hash.Full.t()]
           }}
          | {:error, [Changeset.t()]}
          | {:error, step :: Ecto.Multi.name(), failed_value :: any(),
             changes_so_far :: %{optional(Ecto.Multi.name()) => any()}}
  def import_blocks(options) when is_list(options) do
    ecto_schema_module_to_params_list = import_options_to_ecto_schema_module_to_params_list(options)

    with {:ok, ecto_schema_module_to_changes_list} <-
           ecto_schema_module_to_params_list_to_ecto_schema_module_to_changes_list(ecto_schema_module_to_params_list) do
      insert_ecto_schema_module_to_changes_list(ecto_schema_module_to_changes_list, options)
    end
  end

  @doc """
  Bulk insert internal transactions for a list of transactions.

  ## Options

    * `:addresses`
      * `:params` - `list` of params for `Explorer.Chain.Address.changeset/2`.
      * `:timeout` - the timeout for inserting all addresses.  Defaults to `#{@insert_addresses_timeout}` milliseconds.
    * `:internal_transactions`
      * `:params` - `list` of params for `Explorer.Chain.InternalTransaction.changeset/2`.
      * `:timeout` - the timeout for inserting all internal transactions. Defaults to
        `#{@insert_internal_transactions_timeout}` milliseconds.
    * `:transactions`
      * `:hashes` - `list` of `t:Explorer.Chain.Transaction.t/0` `hash`es that should have their
          `internal_transactions_indexed_at` updated.
      * `:timeout` - the timeout for updating transactions with `:hashes`.  Defaults to
        `#{@update_transactions_timeout}` milliseconds.
    * `:timeout` - the timeout for the whole `c:Ecto.Repo.transaction/0` call.  Defaults to `#{@transaction_timeout}`
      milliseconds.
  """
  @spec import_internal_transactions([
          addresses_option
          | internal_transactions_option
          | timeout_option
          | {:transactions, [{:hashes, [String.t()]} | timeout_option]}
        ]) ::
          {:ok,
           %{
             optional(:addresses) => [Hash.Truncated.t()],
             optional(:internal_transactions) => [
               %{required(:index) => non_neg_integer(), required(:transaction_hash) => Hash.Full.t()}
             ]
           }}
          | {:error, [Changeset.t()]}
          | {:error, step :: Ecto.Multi.name(), failed_value :: any(),
             changes_so_far :: %{optional(Ecto.Multi.name()) => any()}}
  def import_internal_transactions(options) when is_list(options) do
    {transactions_options, import_options} = Keyword.pop(options, :transactions)
    ecto_schema_module_to_params_list = import_options_to_ecto_schema_module_to_params_list(import_options)

    with {:ok, ecto_schema_module_to_changes_list} <-
           ecto_schema_module_to_params_list_to_ecto_schema_module_to_changes_list(ecto_schema_module_to_params_list) do
      timestamps = timestamps()

      ecto_schema_module_to_changes_list
      |> ecto_schema_module_to_changes_list_to_multi(Keyword.put(options, :timestamps, timestamps))
      |> Multi.run(:transactions, fn _ ->
        transaction_hashes = Keyword.get(transactions_options, :hashes)
        transactions_count = length(transaction_hashes)

        query =
          from(
            t in Transaction,
            where: t.hash in ^transaction_hashes,
            update: [set: [internal_transactions_indexed_at: ^timestamps.updated_at]]
          )

        {^transactions_count, result} = Repo.update_all(query, [])

        {:ok, result}
      end)
      |> import_transaction(options)
    end
  end

  @doc """
  The number of `t:Explorer.Chain.Address.t/0`.

      iex> insert_list(2, :address)
      iex> Explorer.Chain.address_count()
      2

  When there are no `t:Explorer.Chain.Address.t/0`, the count is `0`.

      iex> Explorer.Chain.address_count()
      0

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

  When there are addresses, the `reducer` is called for each `t:Explorer.Chain.Address.t/0`.

      iex> [first_address_hash, second_address_hash] = 2 |> insert_list(:address) |> Enum.map(& &1.hash)
      iex> {:ok, address_hash_set} = Explorer.Chain.stream_unfetched_addresses([:hash],
      ...>   MapSet.new([]),
      ...>   fn %Explorer.Chain.Address{hash: hash}, acc ->
      ...>     MapSet.put(acc, hash)
      ...>   end
      ...> )
      ...> first_address_hash in address_hash_set
      true
      ...> second_address_hash in address_hash_set
      true

  When there are no addresses, the `reducer` is never called and the `initial` is returned in an `:ok` tuple.

      iex> {:ok, pid} = Agent.start_link(fn -> 0 end)
      iex> Explorer.Chain.stream_unfetched_addresses([:hash], MapSet.new([]), fn %Explorer.Chain.Address{hash: hash}, acc ->
      ...>   Agent.update(pid, &(&1 + 1))
      ...>   MapSet.put(acc, hash)
      ...> end)
      {:ok, MapSet.new([])}
      iex> Agent.get(pid, & &1)
      0

  """
  @spec stream_unfetched_addresses(
          fields :: [:fetched_balance | :balance_fetched_at | :hash | :contract_code | :inserted_at | :updated_at],
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_addresses(fields, initial, reducer) when is_function(reducer, 2) do
    Repo.transaction(
      fn ->
        query = from(a in Address, where: is_nil(a.balance_fetched_at), select: ^fields)

        query
        |> Repo.stream(timeout: :infinity)
        |> Enum.reduce(initial, reducer)
      end,
      timeout: :infinity
    )
  end

  @doc """
  Returns a stream of all transactions with unfetched internal transactions.
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
            | :public_key
            | :r
            | :s
            | :standard_v
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
        query = from(t in Transaction, where: is_nil(t.internal_transactions_indexed_at), select: ^fields)

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
      iex> insert(:log, transaction_hash: transaction.hash, index: 0)
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
  Calculates the overall missing number of blocks and the ranges of missing blocks.

  `missing_block_numbers/0` does not take into account block numbers that have appeared on-chain after the
  `max_block_number/0`; it only uses the missing blocks in the database between `0` and `max_block_number/0`.

  When there are no `t:Explorer.Chain.Block.t/0`, there can be no missing blocks.

      iex> Explorer.Chain.missing_block_numbers()
      {0, []}

  If the block numbers from `0` to `max_block_number/0` are contiguous, then no block numbers are missing

      iex> insert(:block, number: 0)
      iex> insert(:block, number: 1)
      iex> Explorer.Chain.missing_block_numbers()
      {0, []}

  If there are gaps between `0` and `max_block_number/0`, then the missing numbers are compacted into ranges.  Single
  missing numbers become ranges with the single number as the start and end.

      iex> insert(:block, number: 0)
      iex> insert(:block, number: 2)
      iex> insert(:block, number: 5)
      iex> Explorer.Chain.missing_block_numbers()
      {3, [{1, 1}, {3, 4}]}

  """
  def missing_block_numbers do
    {:ok, {_, missing_count, missing_ranges}} =
      Repo.transaction(fn ->
        query = from(b in Block, select: b.number, order_by: [asc: b.number])

        query
        |> Repo.stream(max_rows: 1000, timeout: :infinity)
        |> Enum.reduce({-1, 0, []}, fn
          num, {prev, missing_count, acc} when prev + 1 == num ->
            {num, missing_count, acc}

          num, {prev, missing_count, acc} ->
            {num, missing_count + (num - prev - 1), [{prev + 1, num - 1} | acc]}
        end)
      end)

    {missing_count, Enum.reverse(missing_ranges)}
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
  Returns the list of collated transactions that occurred recently (10).

      iex> 2 |> insert_list(:transaction) |> with_block()
      iex> insert(:transaction) # unvalidated transaction
      iex> 8 |> insert_list(:transaction) |> with_block()
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
      iex> first_transaction_in_first_block = :transaction |> insert() |> with_block(first_block)
      iex> second_transaction_in_first_block = :transaction |> insert() |> with_block(first_block)
      iex> second_block = insert(:block, number: 2)
      iex> first_transaction_in_second_block = :transaction |> insert() |> with_block(second_block)
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
  @spec recent_collated_transactions([after_hash_option | necessity_by_association_option]) :: [
          Transaction.t()
        ]
  def recent_collated_transactions(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    query =
      from(
        transaction in Transaction,
        where: not is_nil(transaction.block_number) and not is_nil(transaction.index),
        order_by: [desc: transaction.block_number, desc: transaction.index],
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
      iex> :transaction |> insert() |> with_block()
      iex> 8 |> insert_list(:transaction)
      iex> %Scrivener.Page{entries: recent_pending_transactions} = Explorer.Chain.recent_pending_transactions()
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
      iex> %Scrivener.Page{entries: after_first_transaction} = Explorer.Chain.recent_pending_transactions(
      ...>   inserted_after: first_inserted_at
      ...> )
      iex> length(after_first_transaction)
      1
      iex> %Scrivener.Page{entries: after_second_transaction} = Explorer.Chain.recent_pending_transactions(
      ...>   inserted_after: second_inserted_at
      ...> )
      iex> length(after_second_transaction)
      0

  When there are no pending transaction and a collated transaction's inserted_at is used, an empty list is returned

      iex> {:ok, first_inserted_at, 0} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      iex> :transaction |> insert(inserted_at: first_inserted_at) |> with_block()
      iex> {:ok, second_inserted_at, 0} = DateTime.from_iso8601("2016-01-23T23:50:07Z")
      iex> :transaction |> insert(inserted_at: second_inserted_at) |> with_block()
      iex> %Scrivener.Page{entries: entries} = Explorer.Chain.recent_pending_transactions(
      ...>   after_inserted_at: first_inserted_at
      ...> )
      iex> entries
      []

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.
    * `:pagination` - pagination params to pass to scrivener.

  """
  @spec recent_pending_transactions([inserted_after_option | necessity_by_association_option]) :: %Scrivener.Page{
          entries: [Transaction.t()]
        }
  def recent_pending_transactions(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    pagination = Keyword.get(options, :pagination, %{})

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
    |> Repo.paginate(pagination)
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
  Count of `t:Explorer.Chain.Transaction.t/0`.

  With no options or an explicit `pending: nil`, both collated and pending transactions will be counted.

      iex> insert(:transaction)
      iex> :transaction |> insert() |> with_block()
      iex> Explorer.Chain.transaction_count()
      2
      iex> Explorer.Chain.transaction_count(pending: nil)
      2

  To count only collated transactions, pass `pending: false`.

      iex> 2 |> insert_list(:transaction)
      iex> 3 |> insert_list(:transaction) |> with_block()
      iex> Explorer.Chain.transaction_count(pending: false)
      3

  To count only pending transactions, pass `pending: true`.

      iex> 2 |> insert_list(:transaction)
      iex> 3 |> insert_list(:transaction) |> with_block()
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
    * `:pagination` - pagination params to pass to scrivener.

  """
  @spec transaction_hash_to_internal_transactions(Hash.Full.t()) :: %Scrivener.Page{
          entries: [InternalTransaction.t()]
        }
  @spec transaction_hash_to_internal_transactions(Hash.Full.t(), [
          necessity_by_association_option | pagination_option
        ]) :: %Scrivener.Page{entries: [InternalTransaction.t()]}
  def transaction_hash_to_internal_transactions(
        %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash,
        options \\ []
      )
      when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    pagination = Keyword.get(options, :pagination, %{})

    InternalTransaction
    |> for_parent_transaction(hash)
    |> join_associations(necessity_by_association)
    |> where_transaction_has_multiple_internal_transactions()
    |> order_by(:index)
    |> Repo.paginate(pagination)
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
  Converts `transaction` to the status of the `t:Explorer.Chain.Transaction.t/0` whether pending or collated.

  ## Returns

    * `:failed` - the transaction failed without running out of gas
    * `:pending` - the transaction has not be confirmed in a block yet
    * `:out_of_gas` - the transaction failed because it ran out of gas
    * `:success` - the transaction has been confirmed in a block

  """
  @spec transaction_to_status(Transaction.t()) :: :failed | :pending | :out_of_gas | :success
  def transaction_to_status(%Transaction{status: nil}), do: :pending
  def transaction_to_status(%Transaction{status: :ok}), do: :success

  def transaction_to_status(%Transaction{gas: gas, gas_used: gas_used, status: :error}) when gas_used >= gas do
    :out_of_gas
  end

  def transaction_to_status(%Transaction{status: :error}), do: :failed

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

  def create_smart_contract(attrs \\ %{}) do
    %SmartContract{}
    |> SmartContract.changeset(attrs)
    |> Repo.insert()
  end

  defp address_hash_to_transactions(
         %Hash{byte_count: unquote(Hash.Truncated.byte_count())} = address_hash,
         named_arguments
       )
       when is_list(named_arguments) do
    direction = Keyword.get(named_arguments, :direction)
    necessity_by_association = Keyword.get(named_arguments, :necessity_by_association, %{})
    pagination = Keyword.get(named_arguments, :pagination, %{})

    Transaction
    |> join_associations(necessity_by_association)
    |> reverse_chronologically()
    |> where_address_fields_match(address_hash, direction)
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
        changeset = %Changeset{valid?: false}, {:ok, _} ->
          {:error, [changeset]}

        changeset = %Changeset{valid?: false}, {:error, acc_changesets} ->
          {:error, [changeset | acc_changesets]}

        %Changeset{changes: changes, valid?: true}, {:ok, acc_changes} ->
          {:ok, [changes | acc_changes]}

        %Changeset{valid?: true}, {:error, _} = error ->
          error
      end)

    {status, Enum.reverse(acc)}
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

  @spec insert_addresses([%{hash: Hash.Truncated.t()}], [timeout_option | timestamps_option]) ::
          {:ok, [Hash.Truncated.t()]}
  defp insert_addresses(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = sort_address_changes_list(changes_list)

    insert_changes_list(
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: [set: [balance_fetched_at: nil]],
      for: Address,
      timeout: timeout,
      timestamps: timestamps
    )

    {:ok, for(changes <- ordered_changes_list, do: changes.hash)}
  end

  defp sort_address_changes_list(changes_list) do
    Enum.sort_by(changes_list, & &1.hash)
  end

  @import_option_key_to_ecto_schema_module %{
    addresses: Address,
    blocks: Block,
    internal_transactions: InternalTransaction,
    logs: Log,
    transactions: Transaction
  }

  defp import_options_to_ecto_schema_module_to_params_list(options) do
    Enum.reduce(@import_option_key_to_ecto_schema_module, %{}, fn {option_key, ecto_schema_module}, acc ->
      case Keyword.fetch(options, option_key) do
        {:ok, option_value} when is_list(option_value) ->
          Map.put(acc, ecto_schema_module, Keyword.fetch!(option_value, :params))

        :error ->
          acc
      end
    end)
  end

  @spec insert_blocks([map()], [timeout_option | timestamps_option]) :: {:ok, [Hash.t()]} | {:error, [Changeset.t()]}
  defp insert_blocks(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.number, &1.hash})

    {:ok, _} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: :number,
        on_conflict: :replace_all,
        for: Block,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, for(changes <- ordered_changes_list, do: changes.hash)}
  end

  defp insert_ecto_schema_module_to_changes_list(ecto_schema_module_to_changes_list, options) do
    timestamps = timestamps()

    ecto_schema_module_to_changes_list
    |> ecto_schema_module_to_changes_list_to_multi(Keyword.put(options, :timestamps, timestamps))
    |> import_transaction(options)
  end

  defp import_transaction(multi, options) when is_list(options) do
    Repo.transaction(multi, timeout: Keyword.get(options, :timeout, @transaction_timeout))
  end

  defp ecto_schema_module_to_changes_list_to_multi(ecto_schema_module_to_changes_list, options) when is_list(options) do
    timestamps = timestamps()
    full_options = Keyword.put(options, :timestamps, timestamps)

    Multi.new()
    |> run_addresses(ecto_schema_module_to_changes_list, full_options)
    |> run_blocks(ecto_schema_module_to_changes_list, full_options)
    |> run_transactions(ecto_schema_module_to_changes_list, full_options)
    |> run_internal_transactions(ecto_schema_module_to_changes_list, full_options)
    |> run_logs(ecto_schema_module_to_changes_list, full_options)
  end

  @spec insert_internal_transactions([map()], [timestamps_option]) ::
          {:ok, [%{index: non_neg_integer, transaction_hash: Hash.t()}]}
          | {:error, [Changeset.t()]}
  defp insert_internal_transactions(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, internal_transactions} =
      insert_changes_list(
        ordered_changes_list,
        for: InternalTransaction,
        returning: [:index, :transaction_hash],
        timestamps: timestamps
      )

    {:ok,
     for(
       internal_transaction <- internal_transactions,
       do: Map.take(internal_transaction, [:index, :transaction_hash])
     )}
  end

  @spec insert_logs([map()], [timeout_option | timestamps_option]) ::
          {:ok, [%{index: non_neg_integer, transaction_hash: Hash.t()}]}
          | {:error, [Changeset.t()]}
  defp insert_logs(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, logs} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :index],
        on_conflict: :replace_all,
        for: Log,
        returning: [:index, :transaction_hash],
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, for(log <- logs, do: Map.take(log, [:index, :transaction_hash]))}
  end

  defp insert_changes_list(changes_list, options) when is_list(changes_list) do
    ecto_schema_module = Keyword.fetch!(options, :for)

    timestamped_changes_list = timestamp_changes_list(changes_list, Keyword.fetch!(options, :timestamps))

    {_, inserted} =
      Repo.safe_insert_all(
        ecto_schema_module,
        timestamped_changes_list,
        Keyword.delete(options, :for)
      )

    {:ok, inserted}
  end

  @spec insert_transactions([map()], [timeout_option | timestamps_option]) ::
          {:ok, [Hash.t()]} | {:error, [Changeset.t()]}
  defp insert_transactions(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, & &1.hash)

    {:ok, transactions} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: :hash,
        on_conflict: :replace_all,
        for: Transaction,
        returning: [:hash],
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, for(transaction <- transactions, do: transaction.hash)}
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

  defp run_addresses(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Address => addresses_changes} ->
        Multi.run(multi, :addresses, fn _ ->
          insert_addresses(
            addresses_changes,
            timeout: options[:addresses][:timeout] || @insert_addresses_timeout,
            timestamps: Keyword.fetch!(options, :timestamps)
          )
        end)

      _ ->
        multi
    end
  end

  defp run_blocks(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Block => blocks_changes} ->
        Multi.run(multi, :blocks, fn _ ->
          insert_blocks(
            blocks_changes,
            timeout: options[:blocks][:timeout] || @insert_blocks_timeout,
            timestamps: Keyword.fetch!(options, :timestamps)
          )
        end)

      _ ->
        multi
    end
  end

  defp run_transactions(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Transaction => transactions_changes} ->
        Multi.run(multi, :transactions, fn _ ->
          insert_transactions(
            transactions_changes,
            timeout: options[:transations][:timeout] || @insert_transactions_timeout,
            timestamps: Keyword.fetch!(options, :timestamps)
          )
        end)

      _ ->
        multi
    end
  end

  defp run_internal_transactions(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{InternalTransaction => internal_transactions_changes} ->
        Multi.run(multi, :internal_transactions, fn _ ->
          insert_internal_transactions(
            internal_transactions_changes,
            timeout: options[:internal_transactions][:timeout] || @insert_internal_transactions_timeout,
            timestamps: Keyword.fetch!(options, :timestamps)
          )
        end)

      _ ->
        multi
    end
  end

  defp run_logs(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Log => logs_changes} ->
        Multi.run(multi, :logs, fn _ ->
          insert_logs(
            logs_changes,
            timeout: options[:logs][:timeout] || @insert_logs_timeout,
            timestamps: Keyword.fetch!(options, :timestamps)
          )
        end)

      _ ->
        multi
    end
  end

  defp timestamp_params(changes, timestamps) when is_map(changes) do
    Map.merge(changes, timestamps)
  end

  defp timestamp_changes_list(changes_list, timestamps) when is_list(changes_list) do
    Enum.map(changes_list, &timestamp_params(&1, timestamps))
  end

  @spec timestamps() :: timestamps
  defp timestamps do
    now = DateTime.utc_now()
    %{inserted_at: now, updated_at: now}
  end

  defp transaction_hash_to_logs(
         %Hash{byte_count: unquote(Hash.Full.byte_count())} = transaction_hash,
         options
       )
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

  defp where_address_fields_match(query, address_hash, direction \\ nil) do
    address_fields =
      case direction do
        :to -> [:to_address_hash]
        :from -> [:from_address_hash]
        nil -> [:to_address_hash, :from_address_hash]
      end

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

  defp where_transaction_has_multiple_internal_transactions(query) do
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
end
