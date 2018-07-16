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
      select_merge: 3,
      where: 2,
      where: 3
    ]

  alias Ecto.Adapters.SQL
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
    SmartContract
  }

  alias Explorer.Chain.Block.Reward
  alias Explorer.{PagingOptions, Repo}

  @default_paging_options %PagingOptions{page_size: 50}

  @typedoc """
  The name of an association on the `t:Ecto.Schema.t/0`
  """
  @type association :: atom()

  @typedoc """
  Event type where data is broadcasted whenever data is inserted from chain indexing.
  """
  @type chain_event :: :balance_updates | :blocks | :logs | :transactions

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
  @typep on_conflict_option :: {:on_conflict, :nothing | :replace_all}
  @typep paging_options :: {:paging_options, PagingOptions.t()}
  @typep params_option :: {:params, [map()]}
  @typep timeout_option :: {:timeout, timeout}
  @typep timestamps :: %{inserted_at: DateTime.t(), updated_at: DateTime.t()}
  @typep timestamps_option :: {:timestamps, timestamps}
  @typep addresses_option :: {:addresses, [params_option | timeout_option]}
  @typep blocks_option :: {:blocks, [params_option | timeout_option]}
  @typep internal_transactions_option :: {:internal_transactions, [params_option | timeout_option]}
  @typep logs_option :: {:logs, [params_option | timeout_option]}
  @typep receipts_option :: {:receipts, [params_option | timeout_option]}
  @typep transactions_option :: {:transactions, [on_conflict_option | params_option | timeout_option]}

  @doc """
  Estimated count of `t:Explorer.Chain.Address.t/0`.

  Estimated count of addresses
  """
  @spec address_estimated_count() :: non_neg_integer()
  def address_estimated_count do
    %Postgrex.Result{rows: [[rows]]} =
      SQL.query!(Repo, "SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname='addresses'")

    rows
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
    |> where_address_fields_match(hash, direction)
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
  Counts the number of `t:Explorer.Chain.Transaction.t/0` to or from the `address`.
  """
  @spec address_to_transaction_count(Address.t()) :: non_neg_integer()
  def address_to_transaction_count(%Address{hash: hash}) do
    {:ok, %{rows: [[result]]}} =
      SQL.query(
        Repo,
        """
          SELECT COUNT(hash) from
          (
            SELECT t0."hash" address
            FROM "transactions" AS t0
            LEFT OUTER JOIN "internal_transactions" AS i1 ON (i1."transaction_hash" = t0."hash") AND (i1."type" = 'create')
            WHERE (i1."created_contract_address_hash" = $1 AND t0."to_address_hash" IS NULL)

            UNION

            SELECT t0."hash" address
            FROM "transactions" AS t0
            WHERE (t0."to_address_hash" = $1)
            OR (t0."from_address_hash" = $1)
          ) AS hash
        """,
        [hash.bytes]
      )

    result
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

    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions()
    |> where_address_fields_match(address_hash, direction)
    |> join_associations(necessity_by_association)
    |> Repo.all()
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

      iex> Explorer.Chain.update_balances(
      ...>   [
      ...>     %{
      ...>       fetched_balance: 100,
      ...>       fetched_balance_block_number: 1,
      ...>       hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      ...>     }
      ...>   ]
      ...> )
      {:ok,
       [
         %Explorer.Chain.Hash{
           byte_count: 20,
           bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211,
             165, 101, 32, 167, 106, 179, 223, 65, 91>>
         }
       ]}
      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x8bf38d4764929064f2d4d3a56520a76ab3df415b")
      iex> {:ok, address} = Explorer.Chain.hash_to_address(hash)
      iex> address.fetched_balance
      %Explorer.Chain.Wei{value: Decimal.new(100)}
      iex> address.fetched_balance_block_number
      1

  There don't need to be any updates.

      iex> Explorer.Chain.update_balances([])
      {:ok, []}

  Whichever `fetched_balance` is associated with the greater `fetched_balance_block_number` will win if there is a
  conflict.  No matter whether the update has a conflict or not or wins, the hash is always returned due to how
  `RETURNING` works for `ON CONFLICT` in PostgreSQL.

      iex> insert(
      ...>   :address,
      ...>   fetched_balance: 2,
      ...>   fetched_balance_block_number: 2,
      ...>   hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      ...> )
      iex> Explorer.Chain.update_balances(
      ...>   [
      ...>     %{
      ...>       fetched_balance: 3,
      ...>       fetched_balance_block_number: 1,
      ...>       hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      ...>     }
      ...>   ]
      ...> )
      {:ok,
       [
         %Explorer.Chain.Hash{
           byte_count: 20,
           bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211,
             165, 101, 32, 167, 106, 179, 223, 65, 91>>
         }
       ]}
      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x8bf38d4764929064f2d4d3a56520a76ab3df415b")
      iex> {:ok, unchanged_address} = Explorer.Chain.hash_to_address(hash)
      iex> unchanged_address.fetched_balance
      %Explorer.Chain.Wei{value: Decimal.new(2)}
      iex> unchanged_address.fetched_balance_block_number
      2
      iex> Explorer.Chain.update_balances(
      ...>   [
      ...>     %{
      ...>       fetched_balance: 1,
      ...>       fetched_balance_block_number: 3,
      ...>       hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      ...>     }
      ...>   ]
      ...> )
      {:ok,
        [
          %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211,
              165, 101, 32, 167, 106, 179, 223, 65, 91>>
          }
        ]}
      iex> {:ok, changed_address} = Explorer.Chain.hash_to_address(hash)
      iex> changed_address.fetched_balance
      %Explorer.Chain.Wei{value: Decimal.new(1)}
      iex> changed_address.fetched_balance_block_number
      3

  `t:Explorer.Chain.Address.t/0`s when first imported do not have a balance, in such a case, the balance updates win.

      iex> address = insert(:address, hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b")
      iex> address.fetched_balance
      nil
      iex> address.fetched_balance_block_number
      nil
      iex> Explorer.Chain.update_balances(
      ...>   [
      ...>     %{
      ...>       fetched_balance: 3,
      ...>       fetched_balance_block_number: 1,
      ...>       hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      ...>     }
      ...>   ]
      ...> )
      {:ok,
       [
         %Explorer.Chain.Hash{
           byte_count: 20,
           bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211,
             165, 101, 32, 167, 106, 179, 223, 65, 91>>
         }
       ]}
      iex> {:ok, hash} = Explorer.Chain.string_to_address_hash("0x8bf38d4764929064f2d4d3a56520a76ab3df415b")
      iex> {:ok, address} = Explorer.Chain.hash_to_address(hash)
      iex> address.fetched_balance
      %Explorer.Chain.Wei{value: Decimal.new(3)}
      iex> address.fetched_balance_block_number
      1

  ## Options

   * `:addresses`
      * `:timeout` - the timeout for upserting all addresses with the updated balances.  Defaults to
        `#{@insert_addresses_timeout}`.
   * `:timeout` - the timeout for the whole `c:Ecto.Repo.transaction/0` call.  Defaults to `#{@transaction_timeout}`
      milliseconds.

  """
  @spec update_balances(
          [
            %{
              required(:fetched_balance) => non_neg_integer(),
              required(:fetched_balance_block_number) => Block.block_number(),
              required(:hash) => String.t()
            }
          ],
          [
            [{:addresses, [timeout_option]}] | timeout_option
          ]
        ) :: {:ok, [Hash.Address.t()]} | {:error, [Changeset.t()]}
  def update_balances(addresses_params, options \\ []) when is_list(options) do
    with {:ok, changes_list} <- changes_list(addresses_params, for: Address, with: :balance_changeset) do
      timestamps = timestamps()

      insert_addresses(changes_list, timeout: options[:timeout] || @transaction_timeout, timestamps: timestamps)
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

  A `String.t/0` value for `Explorer.Chain.Addres.t/0` `hash` must have 40 hexadecimal characters after the `0x` prefix
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
  @spec hash_to_address(Hash.Address.t()) :: {:ok, Address.t()} | {:error, :not_found}
  def hash_to_address(%Hash{byte_count: unquote(Hash.Address.byte_count())} = hash) do
    query =
      from(
        address in Address,
        preload: [:smart_contract, :contracts_creation_internal_transaction],
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
        where: address.hash in ^hashes
      )

    Repo.all(query)
  end

  def find_contract_address(%Hash{byte_count: unquote(Hash.Address.byte_count())} = hash) do
    query =
      from(
        address in Address,
        preload: [:smart_contract, :contracts_creation_internal_transaction],
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
  Bulk insert blocks from a list of blocks.

  The import returns the unique key(s) for each type of record inserted.

  | Key                      | Value Type                                                                 | Value Description                                                                             |
  |--------------------------|----------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
  | `:addresses`             | `[Explorer.Chain.Hash.t()]`                                                | List of `t:Explorer.Chain.Address.t/0` `hash`                                                 |
  | `:blocks`                | `[Explorer.Chain.Block.t()]`                                               | List of `t:Explorer.Chain.Block.t/0`s                                                   |
  | `:internal_transactions` | `[%{index: non_neg_integer(), transaction_hash: Explorer.Chain.Hash.t()}]` | List of maps of the `t:Explorer.Chain.InternalTransaction.t/0` `index` and `transaction_hash` |
  | `:logs`                  | `[Explorer.Chain.Log.t()]`                                                 | List of `t:Explorer.Chain.Log.t/0`s              |
  | `:transactions`          | `[Explorer.Chain.Hash.t()]`                                                | List of `t:Explorer.Chain.Transaction.t/0` `hash`                                             |

  A completely empty tree can be imported, but options must still be supplied.  It is a non-zero amount of time to
  process the empty options, so if there is nothing to import, you should avoid calling
  `Explorer.Chain.import_blocks/1`.  If you don't supply any options with params, then nothing is run so there result is
  an empty map.

      iex> Explorer.Chain.import_blocks([])
      {:ok, %{}}

  The params for each key are validated using the corresponding `Ecto.Schema` module's `changeset/2` function.  If there
  are errors, they are returned in `Ecto.Changeset.t`s, so that the original, invalid value can be reconstructed for any
  error messages.

   Because there are multiple processes potentially writing to the same tables at the same time,
  `c:Ecto.Repo.insert_all/2`'s
  [`:conflict_target` and `:on_conflict` options](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert_all/3-options) are
  used to perform [upserts](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert_all/3-upserts) on all tables, so that
  a pre-existing unique key will not trigger a failure, but instead replace or otherwise update the row.

  ## Data Notifications

  On successful inserts, processes interested in certain domains of data will be notified
  that new data has been inserted. See `Explorer.Chain.subscribe_to_events/1` for more information.

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
      * `:on_conflict` - Whether to do `:nothing` or `:replace_all` columns when there is a pre-existing transaction
        with the same hash.

        *NOTE*: Because the repository transaction for a pending `Explorer.Chain.Transaction`s could `COMMIT` after the
        repository transaction for that same transaction being collated into a block, writers, it is recomended to use
        `:nothing` for pending transactions and `:replace_all` for collated transactions, so that collated transactions
        win.
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
             optional(:addresses) => [Hash.Address.t()],
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
           ecto_schema_module_to_params_list_to_ecto_schema_module_to_changes_list(ecto_schema_module_to_params_list),
         {:ok, data} <- insert_ecto_schema_module_to_changes_list(ecto_schema_module_to_changes_list, options) do
      broadcast_events(data)
      {:ok, data}
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
             optional(:addresses) => [Hash.Address.t()],
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
      `:key` (a tuple of the lowest/oldest `{block_number}`) and. Results will be the internal
      transactions older than the `block_number` that are passed.

  """
  @spec list_blocks([paging_options | necessity_by_association_option]) :: [Block.t()]
  def list_blocks(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    Block
    |> join_associations(necessity_by_association)
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> Repo.all()
  end

  @doc """
  Returns a stream of unfetched `t:Explorer.Chain.Address.t/0`.

  When there are addresses, the `reducer` is called for each `t:Explorer.Chain.Address.t/0` `hash` and the max
  `t:Explorer.Chain.Block.t/0` `block_number` that address is mentioned.

  An `t:Explorer.Chain.Address.t/0` `hash` can be used as an `t:Explorer.Chain.Block.t/0` `miner_hash`.

      iex> {:ok, miner_hash} = Explorer.Chain.string_to_address_hash("0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      iex> miner = insert(:address, hash: miner_hash)
      iex> insert(:block, miner: miner, number: 34)
      iex> {:ok, address_fields_list} = Explorer.Chain.stream_unfetched_addresses(
      ...>   [],
      ...>   fn address_fields, acc -> [address_fields | acc] end
      ...> )
      iex> address_fields_list
      [
        %{
          block_number: 34,
          hash: %Explorer.Chain.Hash{
            byte_count: 20,
            bytes: <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132,
              89, 192, 16, 79, 223, 94, 152, 122, 202>>
          }
        }
      ]

  An `t:Explorer.Chain.Address.t/0` `hash` can be used as an `t:Explorer.Chain.Transaction.t/0` `from_address_hash`.

      iex> {:ok, from_address_hash} =
      ...>   Explorer.Chain.string_to_address_hash("0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      iex> from_address = insert(:address, hash: from_address_hash)
      iex> block = insert(:block, number: 34)
      iex> :transaction |>
      ...> insert(from_address: from_address) |>
      ...> with_block(block)
      iex> {:ok, address_fields_list} = Explorer.Chain.stream_unfetched_addresses(
      ...>   [],
      ...>   fn address_fields, acc -> [address_fields | acc] end
      ...> )
      iex> %{
      ...>   block_number: 34,
      ...>   hash: %Explorer.Chain.Hash{
      ...>   byte_count: 20,
      ...>   bytes: <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132,
      ...>     89, 192, 16, 79, 223, 94, 152, 122, 202>>
      ...>   }
      ...> } in address_fields_list
      true

  An `t:Explorer.Chain.Address.t/0` `hash` can be used as an `t:Explorer.Chain.Transaction.t/0` `to_address_hash`.

      iex> {:ok, to_address_hash} = Explorer.Chain.string_to_address_hash("0x8e854802d695269a6f1f3fcabb2111d2f5a0e6f9")
      iex> to_address = insert(:address, hash: to_address_hash)
      iex> block = insert(:block, number: 34)
      iex> :transaction |>
      ...> insert(to_address: to_address) |>
      ...> with_block(block)
      iex> {:ok, address_fields_list} = Explorer.Chain.stream_unfetched_addresses(
      ...>   [],
      ...>   fn address_fields, acc -> [address_fields | acc] end
      ...> )
      iex> %{
      ...>   block_number: 34,
      ...>   hash: %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<142, 133, 72, 2, 214, 149, 38, 154, 111, 31, 63, 202,
      ...>       187, 33, 17, 210, 245, 160, 230, 249>>
      ...>   }
      ...> } in address_fields_list
      true

  An `t:Explorer.Chain.Address.t/0` `hash` can be used as an `t:Explorer.Chain.Log.t/0` `address_hash`.

      iex> {:ok, address_hash} = Explorer.Chain.string_to_address_hash("0x8bf38d4764929064f2d4d3a56520a76ab3df415b")
      iex> address = insert(:address, hash: address_hash)
      iex> block = insert(:block, number: 37)
      iex> transaction =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block(block)
      ...> insert(:log, address: address, transaction: transaction)
      iex> {:ok, address_fields_list} = Explorer.Chain.stream_unfetched_addresses(
      ...>   [],
      ...>   fn address_fields, acc -> [address_fields | acc] end
      ...> )
      iex> %{
      iex>   block_number: 37,
      iex>   hash: %Explorer.Chain.Hash{
      iex>     byte_count: 20,
      iex>     bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211,
      iex>       165, 101, 32, 167, 106, 179, 223, 65, 91>>
      iex>   }
      iex> } in address_fields_list
      true

  An `t:Explorer.Chain.Address.t/0` `hash` can be used as an `t:Explorer.Chain.InternalTransaction.t/0`
  `created_contract_address_hash`.

      iex> {:ok, created_contract_address_hash} =
      ...>   Explorer.Chain.string_to_address_hash("0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4")
      iex> created_contract_address = insert(:address, hash: created_contract_address_hash)
      iex> block = insert(:block, number: 37)
      iex> transaction =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block(block)
      iex> insert(
      ...>   :internal_transaction_create,
      ...>   created_contract_address: created_contract_address,
      ...>   index: 0,
      ...>   transaction: transaction
      ...> )
      iex> {:ok, address_fields_list} = Explorer.Chain.stream_unfetched_addresses(
      ...>   [],
      ...>   fn address_fields, acc -> [address_fields | acc] end
      ...> )
      iex> %{
      ...>   block_number: 37,
      ...>   hash: %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<255, 200, 114, 57, 235, 2, 103, 188, 60, 162, 205, 81,
      ...>       209, 47, 191, 39, 142, 2, 204, 180>>
      ...>   }
      ...> } in address_fields_list
      true

  An `t:Explorer.Chain.Address.t/0` `hash` can be used as an `t:Explorer.Chain.InternalTransaction.t/0`
  `from_address_hash`.

      iex> {:ok, from_address_hash} =
      ...>   Explorer.Chain.string_to_address_hash("0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      iex> from_address = insert(:address, hash: from_address_hash)
      iex> block = insert(:block, number: 37)
      iex> transaction =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block(block)
      iex> insert(
      ...>   :internal_transaction_create,
      ...>   from_address: from_address,
      ...>   index: 0,
      ...>   transaction: transaction
      ...> )
      iex> {:ok, address_fields_list} = Explorer.Chain.stream_unfetched_addresses(
      ...>   [],
      ...>   fn address_fields, acc -> [address_fields | acc] end
      ...> )
      iex> %{
      ...>   block_number: 37,
      ...>   hash: %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132,
      ...>       89, 192, 16, 79, 223, 94, 152, 122, 202>>
      ...>   }
      ...> } in address_fields_list
      true

  An `t:Explorer.Chain.Address.t/0` `hash` can be used as an `t:Explorer.Chain.InternalTransaction.t/0`
  `to_address_hash`.

      iex> {:ok, to_address_hash} =
      ...>   Explorer.Chain.string_to_address_hash("0xfdca0da4158740a93693441b35809b5bb463e527")
      iex> to_address = insert(:address, hash: to_address_hash)
      iex> block = insert(:block, number: 38)
      iex> transaction =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block(block)
      iex> insert(
      ...>   :internal_transaction,
      ...>   index: 0,
      ...>   to_address: to_address,
      ...>   transaction: transaction
      ...> )
      iex> {:ok, address_fields_list} = Explorer.Chain.stream_unfetched_addresses(
      ...>   [],
      ...>   fn address_fields, acc -> [address_fields | acc] end
      ...> )
      iex> %{
      ...>   block_number: 38,
      ...>   hash: %Explorer.Chain.Hash{
      ...>     byte_count: 20,
      ...>     bytes: <<253, 202, 13, 164, 21, 135, 64, 169, 54, 147, 68, 27,
      ...>       53, 128, 155, 91, 180, 99, 229, 39>>
      ...>   }
      ...> } in address_fields_list
      true

  Pending `t:Explorer.Chain.Transaction.t/0` `from_address_hash` and `to_address_hash` aren't returned because they
  don't have an associated block number.

      iex> insert(:transaction)
      iex> {:ok, address_fields_list} = Explorer.Chain.stream_unfetched_addresses(
      ...>   [],
      ...>   fn address_fields, acc -> [address_fields | acc] end
      ...> )
      iex> address_fields_list
      []

  When an `t:Explorer.Chain.Address.t/0` `hash` is used multiple times, the max `t:Explorer.Chain.Block.t/0` `number`
  will be returned.

      iex> {:ok, miner_hash} = Explorer.Chain.string_to_address_hash("0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      iex> miner = insert(:address, hash: miner_hash)
      iex> mined_block = insert(:block, miner: miner, number: 7)
      iex> from_transaction_block = insert(:block, number: 6)
      iex> :transaction |>
      ...> insert(from_address: miner) |>
      ...> with_block(from_transaction_block)
      iex> to_transaction_block = insert(:block, number: 5)
      iex> :transaction |>
      ...> insert(to_address: miner) |>
      ...> with_block(to_transaction_block)
      iex> log_block = insert(:block, number: 4)
      iex> log_transaction =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block(log_block)
      iex> insert(:log, address: miner, transaction: log_transaction)
      iex> from_internal_transaction_block = insert(:block, number: 3)
      iex> from_internal_transaction_transaction =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block(from_internal_transaction_block)
      iex> insert(
      ...>   :internal_transaction_create,
      ...>   from_address: miner,
      ...>   index: 0,
      ...>   transaction: from_internal_transaction_transaction
      ...> )
      iex> to_internal_transaction_block = insert(:block, number: 2)
      iex> to_internal_transaction_transaction =
      ...>   :transaction |>
      ...>   insert() |>
      ...>   with_block(to_internal_transaction_block)
      iex> insert(
      ...>   :internal_transaction_create,
      ...>   index: 0,
      ...>   to_address: miner,
      ...>   transaction: to_internal_transaction_transaction
      ...> )
      iex> {:ok, hash_to_block_number} = Explorer.Chain.stream_unfetched_addresses(
      ...>   %{},
      ...>   fn %{block_number: block_number, hash: hash}, acc -> Map.put(acc, hash, block_number) end
      ...> )
      iex> hash_to_block_number[miner_hash]
      7
      iex> Enum.max(
      ...>   [
      ...>     mined_block.number,
      ...>     from_transaction_block.number,
      ...>     to_transaction_block.number,
      ...>     log_block.number,
      ...>     from_internal_transaction_block.number,
      ...>     to_internal_transaction_block.number
      ...>   ]
      ...> )
      7

  When there are no addresses, the `reducer` is never called and the `initial` is returned in an `:ok` tuple.

      iex> {:ok, pid} = Agent.start_link(fn -> 0 end)
      iex> Explorer.Chain.stream_unfetched_addresses([], fn address_fields, acc ->
      ...>   Agent.update(pid, &(&1 + 1))
      ...>   [address_fields | acc]
      ...> end)
      {:ok, []}
      iex> Agent.get(pid, & &1)
      0

  """
  @spec stream_unfetched_addresses(
          initial :: accumulator,
          reducer ::
            (entry :: %{block_number: Block.block_number(), hash: Hash.Address.t()}, accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_addresses(initial, reducer) when is_function(reducer, 2) do
    Repo.transaction(
      fn ->
        query =
          from(
            address in Address,
            left_join: internal_transaction in InternalTransaction,
            on:
              address.hash in [
                internal_transaction.created_contract_address_hash,
                internal_transaction.from_address_hash,
                internal_transaction.to_address_hash
              ],
            left_join: log in Log,
            on: log.address_hash == address.hash,
            left_join: transaction in Transaction,
            on:
              transaction.hash in [internal_transaction.transaction_hash, log.transaction_hash] or
                address.hash in [transaction.from_address_hash, transaction.to_address_hash],
            left_join: block in Block,
            on: block.hash == transaction.block_hash or block.miner_hash == address.hash,
            where: is_nil(address.fetched_balance),
            group_by: address.hash,
            having: not is_nil(max(block.number)),
            select: %{block_number: max(block.number), hash: address.hash}
          )

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
  Calculates the ranges of missing blocks in `range`.

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
                  FROM blocks)
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
  def subscribe_to_events(event_type) when event_type in ~w(blocks logs transactions)a do
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
      `:key` (a tuple of the lowest/oldest `{index}`) and. Results will be the internal transactions older than
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
    |> Repo.all()
  end

  @doc """
  Finds all `t:Explorer.Chain.Log.t/0`s for `t:Explorer.Chain.Transaction.t/0`.

  ## Options

    * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Log.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Log.t/0` will not be included in the page `entries`.
    * `:paging_options` - a `t:Explorer.PagingOptions.t/0` used to specify the `:page_size` and
      `:key` (a tuple of the lowest/oldest `{index}`) and. Results will be the transactions older than
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

  @spec address_hash_to_smart_contract(%Explorer.Chain.Hash{}) :: %Explorer.Chain.SmartContract{}
  def address_hash_to_smart_contract(%Explorer.Chain.Hash{} = address_hash) do
    query =
      from(
        smart_contract in SmartContract,
        where: smart_contract.address_hash == ^address_hash
      )

    Repo.one(query)
  end

  defp broadcast_event_data(event_type, event_data) do
    Registry.dispatch(Registry.ChainEvents, event_type, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, {:chain_event, event_type, event_data})
      end
    end)
  end

  defp broadcast_events(data) do
    for {event_type, event_data} <- data, event_type in ~w(blocks logs transactions)a do
      broadcast_event_data(event_type, event_data)
    end
  end

  @spec changes_list(params :: [map], [{:for, module} | {:with, atom}]) :: {:ok, [map]} | {:error, [Changeset.t()]}
  defp changes_list(params, options) when is_list(options) do
    ecto_schema_module = Keyword.fetch!(options, :for)
    changeset_function_name = Keyword.get(options, :with, :changeset)
    struct = ecto_schema_module.__struct__()

    {status, acc} =
      params
      |> Stream.map(&apply(ecto_schema_module, changeset_function_name, [struct, &1]))
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

  defp fetch_transactions(paging_options \\ nil) do
    Transaction
    |> select_merge([transaction], %{
      created_contract_address_hash:
        type(
          fragment(
            ~s[
              (SELECT i."created_contract_address_hash"
              FROM "internal_transactions" AS i
              WHERE (i."transaction_hash" = ?) AND (i."type" = 'create')
              LIMIT 1)
              ],
            transaction.hash
          ),
          Explorer.Chain.Hash.Address
        )
    })
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

  @spec insert_addresses([%{hash: Hash.Address.t()}], [timeout_option | timestamps_option]) :: {:ok, [Hash.Address.t()]}
  defp insert_addresses(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = sort_address_changes_list(changes_list)

    insert_changes_list(
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict:
        from(
          address in Address,
          update: [
            set: [
              contract_code: fragment("COALESCE(?, EXCLUDED.contract_code)", address.contract_code),
              # ARGMAX on two columns
              fetched_balance:
                fragment(
                  """
                  CASE WHEN EXCLUDED.fetched_balance_block_number IS NOT NULL AND
                            (? IS NULL OR
                             EXCLUDED.fetched_balance_block_number >= ?) THEN
                              EXCLUDED.fetched_balance
                       ELSE ?
                  END
                  """,
                  address.fetched_balance_block_number,
                  address.fetched_balance_block_number,
                  address.fetched_balance
                ),
              # MAX on two columns
              fetched_balance_block_number:
                fragment(
                  """
                  CASE WHEN EXCLUDED.fetched_balance_block_number IS NOT NULL AND
                            (? IS NULL OR
                             EXCLUDED.fetched_balance_block_number >= ?) THEN
                              EXCLUDED.fetched_balance_block_number
                       ELSE ?
                  END
                  """,
                  address.fetched_balance_block_number,
                  address.fetched_balance_block_number,
                  address.fetched_balance_block_number
                )
            ]
          ]
        ),
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

  @spec insert_blocks([map()], [timeout_option | timestamps_option]) :: {:ok, [Block.t()]} | {:error, [Changeset.t()]}
  defp insert_blocks(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.number, &1.hash})

    {:ok, blocks} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: :number,
        on_conflict: :replace_all,
        for: Block,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, blocks}
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

  @spec insert_internal_transactions([map], [timeout_option | timestamps_option]) ::
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
        conflict_target: [:transaction_hash, :index],
        for: InternalTransaction,
        on_conflict: :replace_all,
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
          {:ok, [Log.t()]}
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
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, logs}
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

  @spec insert_transactions([map()], [on_conflict_option | timeout_option | timestamps_option]) ::
          {:ok, [Hash.t()]} | {:error, [Changeset.t()]}
  defp insert_transactions(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)
    on_conflict = Keyword.fetch!(named_arguments, :on_conflict)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, & &1.hash)

    {:ok, transactions} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: :hash,
        on_conflict: on_conflict,
        for: Transaction,
        returning: [:hash],
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, for(transaction <- transactions, do: transaction.hash)}
  end

  defp handle_paging_options(query, nil), do: query

  defp handle_paging_options(query, paging_options) do
    query
    |> page_transaction(paging_options)
    |> limit(^paging_options.page_size)
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

  defp run_addresses(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Address => addresses_changes} ->
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :addresses, fn _ ->
          insert_addresses(
            addresses_changes,
            timeout: options[:addresses][:timeout] || @insert_addresses_timeout,
            timestamps: timestamps
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
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :blocks, fn _ ->
          insert_blocks(
            blocks_changes,
            timeout: options[:blocks][:timeout] || @insert_blocks_timeout,
            timestamps: timestamps
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
        # check required options as early as possible
        transactions_options = Keyword.fetch!(options, :transactions)
        on_conflict = Keyword.fetch!(transactions_options, :on_conflict)
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :transactions, fn _ ->
          insert_transactions(
            transactions_changes,
            on_conflict: on_conflict,
            timeout: transactions_options[:timeout] || @insert_transactions_timeout,
            timestamps: timestamps
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
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :internal_transactions, fn _ ->
          insert_internal_transactions(
            internal_transactions_changes,
            timeout: options[:internal_transactions][:timeout] || @insert_internal_transactions_timeout,
            timestamps: timestamps
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
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :logs, fn _ ->
          insert_logs(
            logs_changes,
            timeout: options[:logs][:timeout] || @insert_logs_timeout,
            timestamps: timestamps
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

  defp where_address_fields_match(query, address_hash, :to) do
    where(query, [t], t.to_address_hash == ^address_hash)
  end

  defp where_address_fields_match(query, address_hash, :from) do
    where(query, [t], t.from_address_hash == ^address_hash)
  end

  defp where_address_fields_match(%Ecto.Query{from: {_table, InternalTransaction}} = query, address_hash, nil) do
    where(
      query,
      [it],
      it.to_address_hash == ^address_hash or it.from_address_hash == ^address_hash or
        it.created_contract_address_hash == ^address_hash
    )
  end

  defp where_address_fields_match(%Ecto.Query{from: {_table, Transaction}} = query, address_hash, nil) do
    where(
      query,
      [t],
      t.to_address_hash == ^address_hash or t.from_address_hash == ^address_hash or
        (is_nil(t.to_address_hash) and
           ^address_hash.bytes in fragment(
             ~s[
            (SELECT i."created_contract_address_hash"
            FROM "internal_transactions" AS i
            WHERE (i."transaction_hash" = ?) AND (i."type" = 'create')
            LIMIT 1)
          ],
             t.hash
           ))
    )
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
end
