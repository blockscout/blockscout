defmodule Explorer.Chain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query, only: [from: 2, or_where: 3, order_by: 2, preload: 2, where: 2, where: 3]

  alias Explorer.Chain.{
    Address,
    Block,
    BlockTransaction,
    InternalTransaction,
    Log,
    Receipt,
    Transaction,
    Wei
  }

  alias Explorer.Repo.NewRelic, as: Repo

  # Types

  @typedoc """
  The name of an association on the `t:Ecto.Schema.t/0`
  """
  @type association :: atom()

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

  @typep direction_option :: :to | :from
  @typep necessity_by_association_option :: {:necessity_by_association, necessity_by_association}
  @typep pagination_option :: {:pagination, pagination}

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
  def address_to_transactions(address = %Address{}, options \\ [])
      when is_list(options) do
    address_id_to_transactions(address.id, options)
  end

  @doc """
  The `t:Explorer.Chain.Address.t/0` `balance` in `unit`.
  """
  @spec balance(Address.t(), :wei) :: Wei.t() | nil
  @spec balance(Address.t(), :gwei) :: Wei.gwei() | nil
  @spec balance(Address.t(), :ether) :: Wei.ether() | nil
  def balance(%Address{balance: balance}, unit) do
    case balance do
      nil -> nil
      _ -> Wei.to(balance, unit)
    end
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
  def block_to_transactions(%Block{id: block_id}, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    pagination = Keyword.get(options, :pagination, %{})

    query =
      from(
        transaction in Transaction,
        inner_join: block in assoc(transaction, :block),
        where: block.id == ^block_id,
        order_by: [desc: transaction.inserted_at]
      )

    query
    |> join_associations(necessity_by_association)
    |> Repo.paginate(pagination)
  end

  @doc """
  Counts the number of `t:Explorer.Chain.Transaction.t/0` in the `block`.
  """
  @spec block_to_transaction_count(Block.t()) :: non_neg_integer()
  def block_to_transaction_count(%Block{id: block_id}) do
    query =
      from(
        block_transaction in BlockTransaction,
        join: block in assoc(block_transaction, :block),
        where: block_transaction.block_id == ^block_id
      )

    Repo.aggregate(query, :count, :block_id)
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

  ## Examples

      iex> Explorer.Addresses.create_address(%{field: value})
      {:ok, %Address{}}

      iex> Explorer.Addresses.create_address(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_address(map()) :: {:ok, Address.t()} | {:error, Ecto.Changeset.t()}
  def create_address(attrs \\ %{}) do
    %Address{}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Ensures that an `t:Explorer.Address.t/0` exists with the given `hash`.

  If a `t:Explorer.Address.t/0` with `hash` already exists, it is returned

      iex> Explorer.Addresses.ensure_hash_address(existing_hash)
      {:ok, %Address{}}

  If a `t:Explorer.Address.t/0` does not exist with `hash`, it is created and returned

      iex> Explorer.Addresses.ensure_hash_address(new_hash)
      {:ok, %Address{}}

  There is a chance of a race condition when interacting with the database: the `t:Explorer.Address.t/0` may not exist
  when first checked, then already exist when it is tried to be created because another connection creates the addres,
  then another process deletes the address after this process's connection see it was created, but before it can be
  retrieved.  In scenario, the address may be not found as only one retry is attempted to prevent infinite loops.

      iex> Explorer.Addresses.ensure_hash_address(flicker_hash)
      {:error, :not_found}

  """
  @spec ensure_hash_address(Address.hash()) :: {:ok, Address.t()} | {:error, :not_found}
  def ensure_hash_address(hash) when is_binary(hash) do
    with {:error, :not_found} <- hash_to_address(hash),
         {:error, _} <- create_address(%{hash: hash}) do
      # assume race condition occurred and someone else created the address between the first
      # hash_to_address and create_address
      hash_to_address(hash)
    end
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
      ...>     receipt: Explorer.Chain.Receipt{gas_used: Decimal.new(2)}
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
  @spec gas_price(Transaction.t(), :wei) :: Wei.t()
  @spec gas_price(Transaction.t(), :gwei) :: Wei.gwei()
  @spec gas_price(Transaction.t(), :ether) :: Wei.ether()
  def gas_price(%Transaction{gas_price: gas_price}, unit) do
    Wei.to(gas_price, unit)
  end

  @doc """
  Converts `t:Explorer.Chain.Address.t/0` `hash` to the `t:Explorer.Chain.Address.t/0` with that `hash`.

  Returns `{:ok, %Explorer.Chain.Address{}}` if found

      iex> hash_to_address("0x0addressaddressaddressaddressaddressaddr")
      {:ok, %Explorer.Chain.Address{}}

  Returns `{:error, :not_found}` if not found

      iex> hash_to_address("0x1addressaddressaddressaddressaddressaddr")
      {:error, :not_found}

  """
  @spec hash_to_address(Address.hash()) :: {:ok, Address.t()} | {:error, :not_found}
  def hash_to_address(hash) do
    Address
    |> where_hash(hash)
    |> preload([:credit, :debit])
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      address -> {:ok, address}
    end
  end

  @doc """
  Converts `t:Explorer.Chain.Transaction.t/0` `hash` to the `t:Explorer.Chain.Transaction.t/0` with that `hash`.

  Returns `{:ok, %Explorer.Chain.Transaction{}}` if found

      iex> hash_to_transaction("0x0addressaddressaddressaddressaddressaddr")
      {:ok, %Explorer.Chain.Transaction{}}

  Returns `{:error, :not_found}` if not found

      iex> hash_to_transaction("0x1addressaddressaddressaddressaddressaddr")
      {:error, :not_found}

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Transaction.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
  """
  @spec hash_to_transaction(Transaction.hash(), [necessity_by_association_option]) ::
          {:ok, Transaction.t()} | {:error, :not_found}
  def hash_to_transaction(hash, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Transaction
    |> join_associations(necessity_by_association)
    |> where_hash(hash)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      transaction -> {:ok, transaction}
    end
  end

  @doc """
  Converts `t:Explorer.Address.t/0` `id` to the `t:Explorer.Address.t/0` with that `id`.

  Returns `{:ok, %Explorer.Address{}}` if found

      iex> id_to_address(123)
      {:ok, %Address{}}

  Returns `{:error, :not_found}` if not found

      iex> id_to_address(456)
      {:error, :not_found}

  """
  @spec id_to_address(id :: non_neg_integer()) :: {:ok, Address.t()} | {:error, :not_found}
  def id_to_address(id) do
    Address
    |> Repo.get(id)
    |> case do
      nil ->
        {:error, :not_found}

      address ->
        {:ok, Repo.preload(address, [:credit, :debit])}
    end
  end

  @doc """
  The last `t:Explorer.Chain.Transaction.t/0` `id`.
  """
  @spec last_transaction_id([{:pending, boolean()}]) :: non_neg_integer()
  def last_transaction_id(options \\ []) when is_list(options) do
    query =
      from(
        t in Transaction,
        select: t.id,
        order_by: [desc: t.id],
        limit: 1
      )

    query
    |> where_pending(options)
    |> Repo.one()
    |> Kernel.||(0)
  end

  @doc """
  Finds all `t:Explorer.Chain.Transaction.t/0` in the `t:Explorer.Chain.Block.t/0`.

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.Block.t/0` has no associated record for that association, then the
      `t:Explorer.Chain.Transaction.t/0` will not be included in the page `entries`.
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
  The maximum `t:Explorer.Chain.Block.t/0` `number`
  """
  @spec max_block_number() :: Block.block_number()
  def max_block_number do
    Repo.aggregate(Block, :max, :number)
  end

  @doc """
  Finds `t:Explorer.Chain.Block.t/0` with `number`
  """
  @spec number_to_block(Block.block_number()) :: {:ok, Block.t()} | {:error, :not_found}
  def number_to_block(number) do
    Block
    |> where(number: ^number)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  @doc """
  Count of `t:Explorer.Chain.Transaction.t/0`.

  ## Options

  * `:pending`
    * `true` - only count pending transactions
    * `false` - count all transactions

  """
  @spec transaction_count([{:pending, boolean()}]) :: non_neg_integer()
  def transaction_count(options \\ []) when is_list(options) do
    Transaction
    |> where_pending(options)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  `t:Explorer.Chain.InternalTransaction/0`s in `t:Explorer.Chain.Transaction.t/0` with `hash`

  This function excludes any internal transactions that have no siblings within the parent transaction.

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.
  * `:pagination` - pagination params to pass to scrivener.

  """
  @spec transaction_hash_to_internal_transactions(Transaction.hash()) :: [InternalTransaction.t()]
  def transaction_hash_to_internal_transactions(hash, options \\ [])
      when is_binary(hash) and is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    pagination = Keyword.get(options, :pagination, %{})

    InternalTransaction
    |> for_parent_transaction(hash)
    |> join_associations(necessity_by_association)
    |> where(
      [_it, t],
      fragment(
        "(SELECT COUNT(sibling.id) FROM internal_transactions as sibling WHERE sibling.transaction_id = ?) > 1",
        t.id
      )
    )
    |> order_by(:index)
    |> Repo.paginate(pagination)
  end

  @doc """
  Returns the list of transactions that occurred recently (10) before `t:Explorer.Chain.Transaction.t/0` `id`.

  ## Examples

      iex> Explorer.Chain.list_transactions_before_id(id)
      [%Explorer.Chain.Transaction{}, ...]

  ## Options

  * `:necessity_by_association` - use to load `t:association/0` as `:required` or `:optional`.  If an association is
      `:required`, and the `t:Explorer.Chain.InternalTransaction.t/0` has no associated record for that association,
      then the `t:Explorer.Chain.InternalTransaction.t/0` will not be included in the list.

  """
  @spec transactions_recently_before_id(id :: non_neg_integer, [necessity_by_association_option]) :: [
          Transaction.t()
        ]
  def transactions_recently_before_id(id, options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Transaction
    |> join_associations(necessity_by_association)
    |> recently_before_id(id)
    |> where_pending(options)
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
  def transaction_to_status(%Transaction{receipt: %Receipt{status: 1}}), do: :success

  def transaction_to_status(%Transaction{
        gas: gas,
        receipt: %Receipt{gas_used: gas_used, status: 0}
      })
      when gas_used >= gas do
    :out_of_gas
  end

  def transaction_to_status(%Transaction{receipt: %Receipt{status: 0}}), do: :failed

  @doc """
  Updates `balance` of `t:Explorer.Address.t/0` with `hash`.

  If `t:Explorer.Address.t/0` with `hash` does not already exist, it is created first.
  """
  @spec update_balance(Address.hash(), Address.balance()) ::
          {:ok, Address.t()} | {:error, Ecto.Changeset.t()} | {:error, reason :: term}
  def update_balance(hash, balance) when is_binary(hash) do
    changes = %{
      balance: balance
    }

    with {:ok, address} <- ensure_hash_address(hash) do
      address
      |> Address.balance_changeset(changes)
      |> Repo.update()
    end
  end

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

  defp address_id_to_transactions(address_id, named_arguments)
       when is_integer(address_id) and is_list(named_arguments) do
    address_fields =
      case Keyword.get(named_arguments, :direction) do
        :to -> [:to_address_id]
        :from -> [:from_address_id]
        nil -> [:to_address_id, :from_address_id]
      end

    necessity_by_association = Keyword.get(named_arguments, :necessity_by_association, %{})
    pagination = Keyword.get(named_arguments, :pagination, %{})

    Transaction
    |> join_associations(necessity_by_association)
    |> reverse_chronologically()
    |> where_address_fields_match(address_fields, address_id)
    |> Repo.paginate(pagination)
  end

  defp for_parent_transaction(query, hash) when is_binary(hash) do
    from(
      child in query,
      inner_join: transaction in assoc(child, :transaction),
      where: fragment("lower(?)", transaction.hash) == ^String.downcase(hash)
    )
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

  defp recently_before_id(query, id) do
    from(
      q in query,
      where: q.id < ^id,
      order_by: [desc: q.id],
      limit: 10
    )
  end

  defp reverse_chronologically(query) do
    from(q in query, order_by: [desc: q.inserted_at, desc: q.id])
  end

  defp transaction_hash_to_logs(transaction_hash, options)
       when is_binary(transaction_hash) and is_list(options) do
    lower_transaction_hash = String.downcase(transaction_hash)
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    pagination = Keyword.get(options, :pagination, %{})

    query =
      from(
        log in Log,
        join: transaction in assoc(log, :transaction),
        where: fragment("lower(?)", transaction.hash) == ^lower_transaction_hash,
        order_by: [asc: :index]
      )

    query
    |> join_associations(necessity_by_association)
    |> Repo.paginate(pagination)
  end

  defp where_address_fields_match(query, address_fields, address_id) do
    Enum.reduce(address_fields, query, fn field, query ->
      or_where(query, [t], field(t, ^field) == ^address_id)
    end)
  end

  defp where_hash(query, hash) do
    from(
      q in query,
      where: fragment("lower(?)", q.hash) == ^String.downcase(hash)
    )
  end

  defp where_pending(query, options) when is_list(options) do
    pending = Keyword.get(options, :pending, false)

    where_pending(query, pending)
  end

  defp where_pending(query, false), do: query

  defp where_pending(query, true) do
    from(
      transaction in query,
      where:
        fragment(
          "NOT EXISTS (SELECT true FROM receipts WHERE receipts.transaction_id = ?)",
          transaction.id
        )
    )
  end
end
