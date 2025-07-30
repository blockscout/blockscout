defmodule Explorer.Chain.Address.CoinBalance do
  @moduledoc """
  The `t:Explorer.Chain.Wei.t/0` `value` of `t:Explorer.Chain.Address.t/0` at the end of a `t:Explorer.Chain.Block.t/0`
  `t:Explorer.Chain.Block.block_number/0`.
  """

  use Explorer.Schema

  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Block, Hash, InternalTransaction, Transaction, Wei}
  alias Explorer.Chain.Address.CoinBalance

  @optional_fields ~w(value value_fetched_at)a
  @required_fields ~w(address_hash block_number)a
  @allowed_fields @optional_fields ++ @required_fields

  @typedoc """
   * `address` - the `t:Explorer.Chain.Address.t/0` with `value` at end of `block_number`.
   * `address_hash` - foreign key for `address`.
   * `block_number` - the `t:Explorer.Chain.Block.block_number/0` for the `t:Explorer.Chain.Block.t/0` at the end of
       which `address` had `value`.  When `block_number` is the greatest `t:Explorer.Chain.Block.block_number/0` for a
       given `address`, the `t:Explorer.Chain.Address.t/0` `fetched_coin_balance_block_number` will match this value.
   * `inserted_at` - When the balance was first inserted into the database.
   * `updated_at` - When the balance was last updated.
   * `value` - the value of `address` at the end of the `t:Explorer.Chain.Block.block_number/0` for the
       `t:Explorer.Chain.Block.t/0`.  When `block_number` is the greatest `t:Explorer.Chain.Block.block_number/0` for a
       given `address`, the `t:Explorer.Chain.Address.t/0` `fetched_coin_balance` will match this value.
   * `value_fetched_at` - when `value` was fetched.
  """
  @primary_key false
  typed_schema "address_coin_balances" do
    field(:block_number, :integer) :: Block.block_number()
    field(:value, Wei)
    field(:value_fetched_at, :utc_datetime_usec)
    field(:delta, Wei, virtual: true)
    field(:transaction_hash, Hash.Full, virtual: true)
    field(:block_timestamp, :utc_datetime_usec, virtual: true)

    timestamps()

    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address, null: false)
  end

  @doc """
  Builds a query to fetch the timestamp and value of the most recent coin balance for a given address.

  This function constructs a query that retrieves the latest coin balance record
  for the specified address and joins it with block information to get the
  timestamp when that balance was recorded. The query ensures that only
  consensus blocks (not uncle blocks) are considered for the balance data.

  ## Parameters
  - `address_hash`: The address hash to look up the most recent coin balance for

  ## Returns
  - An Ecto query that when executed returns a map with:
    - `timestamp`: The timestamp when the block containing the latest balance was mined
    - `value`: The coin balance value in Wei at that block
  """
  @spec last_coin_balance_timestamp(Hash.Address.t()) :: Ecto.Query.t()
  def last_coin_balance_timestamp(address_hash) do
    coin_balance_query =
      CoinBalance
      |> where([cb], cb.address_hash == ^address_hash)
      |> last(:block_number)
      |> select([cb, b], %{block_number: cb.block_number, value: cb.value})

    from(
      cb in subquery(coin_balance_query),
      inner_join: block in Block,
      on: cb.block_number == block.number,
      where: block.consensus == true,
      select: %{timestamp: block.timestamp, value: cb.value}
    )
  end

  def changeset(%__MODULE__{} = balance, params) do
    balance
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:block_number, name: :address_coin_balances_address_hash_block_number_index)
  end

  @doc """
  Query to fetch latest coin balance for the given address
  """
  @spec latest_coin_balance_query(Hash.Address.t(), non_neg_integer()) :: Ecto.Query.t()
  def latest_coin_balance_query(address_hash, stale_balance_window) do
    from(
      cb in __MODULE__,
      where: cb.address_hash == ^address_hash,
      where: cb.block_number >= ^stale_balance_window,
      where: is_nil(cb.value_fetched_at),
      order_by: [desc: :block_number],
      limit: 1
    )
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
            (entry :: %{address_hash: Hash.Address.t(), block_number: Block.block_number()}, accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_unfetched_balances(initial, reducer, limited? \\ false) when is_function(reducer, 2) do
    query =
      from(
        balance in CoinBalance,
        where: is_nil(balance.value_fetched_at),
        select: %{address_hash: balance.address_hash, block_number: balance.block_number}
      )

    query
    |> add_coin_balances_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Retrieves the most recent coin balance for an address at or before a specified block number.

  This function queries the coin balance records for the given address hash,
  filtering for balances at or before the specified block number. It returns
  the most recent balance record, including calculated delta values and block
  timestamps. The query uses a subquery approach to efficiently find the
  latest balance while computing the difference from the previous balance.

  ## Parameters
  - `address_hash`: Hash.Address.t() - The address hash to query balances for
  - `block_number`: Block.block_number() - The maximum block number to consider
  - `options`: keyword() - Query options including `:api?` for replica selection

  ## Returns
  - `t() | nil` - The coin balance record with delta and timestamp fields, or
    `nil` if no balance exists for the address at or before the block number
  """
  @spec get_coin_balance(Hash.Address.t(), Block.block_number(), keyword()) :: t() | nil
  def get_coin_balance(address_hash, block_number, options \\ []) do
    query = fetch_coin_balance(address_hash, block_number)

    Chain.select_repo(options).one(query)
  end

  @doc """
  Retrieves paginated coin balance records for a given address with timestamp interpolation.

  This function fetches coin balance history for an address, applying pagination
  and performing timestamp calculations for blocks. It includes an optimization
  that returns an empty list immediately when the paging key is `{0}`, avoiding
  unnecessary database queries. For other cases, it processes balances by
  filtering records with values, calculating block timestamp ranges, and
  interpolating timestamps for intermediate blocks when multiple blocks are
  present.

  ## Parameters
  - `address`: Address.t() - The address record to fetch coin balances for
  - `options`: [Chain.paging_options() | Chain.api?()] - Query options including
    paging configuration and API mode selection

  ## Returns
  - `[t()]` - List of coin balance records sorted by block number in descending
    order, with interpolated timestamps, or empty list if paging key is `{0}` or
    no balances exist
  """
  @spec address_to_coin_balances(Address.t(), [Chain.paging_options() | Chain.api?()]) :: [t()]
  def address_to_coin_balances(address, options) do
    paging_options = Keyword.get(options, :paging_options, PagingOptions.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        address_to_coin_balances_internal(address, options, paging_options)
    end
  end

  defp address_to_coin_balances_internal(address, options, paging_options) do
    balances_raw =
      address.hash
      |> fetch_coin_balances(paging_options)
      |> page_coin_balances(paging_options)
      |> Chain.select_repo(options).all()
      |> preload_transactions(options)

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

      min_block_timestamp = find_block_timestamp(min_block_number, options)
      max_block_timestamp = find_block_timestamp(max_block_number, options)

      min_block_unix_timestamp =
        min_block_timestamp
        |> Timex.to_unix()

      max_block_unix_timestamp =
        max_block_timestamp
        |> Timex.to_unix()

      blocks_delta = max_block_number - min_block_number

      balances_with_dates =
        if blocks_delta > 0 do
          add_block_timestamp_to_balances(
            balances_raw_filtered,
            min_block_number,
            min_block_unix_timestamp,
            max_block_unix_timestamp,
            blocks_delta
          )
        else
          add_min_block_timestamp_to_balances(balances_raw_filtered, min_block_unix_timestamp)
        end

      balances_with_dates
      |> Enum.sort(fn balance1, balance2 -> balance1.block_number >= balance2.block_number end)
    end
  end

  # Here we fetch from DB one transaction per one coin balance. It's much more faster than LEFT OUTER JOIN which was before.
  defp preload_transactions(balances, options) do
    tasks =
      Enum.map(balances, fn balance ->
        Task.async(fn -> preload_transactions_task(balance, options) end)
      end)

    tasks
    |> Task.yield_many(120_000)
    |> Enum.zip(balances)
    |> Enum.map(fn {{task, res}, balance} ->
      case res do
        {:ok, hash} ->
          put_transaction_hash(hash, balance)

        {:exit, _reason} ->
          balance

        nil ->
          Task.shutdown(task, :brutal_kill)
          balance
      end
    end)
  end

  defp preload_transactions_task(balance, options) do
    transaction_hash =
      balance
      |> preload_transaction_query()
      |> Chain.select_repo(options).one()

    if is_nil(transaction_hash) do
      balance
      |> preload_internal_transaction_query()
      |> Chain.select_repo(options).one()
    else
      transaction_hash
    end
  end

  defp preload_transaction_query(balance) do
    Transaction
    |> where(
      [transaction],
      transaction.block_number == ^balance.block_number and
        (transaction.value > ^0 or (transaction.gas_price > ^0 and transaction.gas_used > ^0)) and
        (transaction.to_address_hash == ^balance.address_hash or
           transaction.from_address_hash == ^balance.address_hash)
    )
    |> select([transaction], transaction.hash)
    |> limit(1)
  end

  defp preload_internal_transaction_query(balance) do
    InternalTransaction
    |> where(
      [internal_transaction],
      internal_transaction.block_number == ^balance.block_number and
        internal_transaction.type in ~w(call create create2 selfdestruct)a and
        (is_nil(internal_transaction.call_type) or internal_transaction.call_type == :call) and
        internal_transaction.value > ^0 and is_nil(internal_transaction.error) and
        (internal_transaction.to_address_hash == ^balance.address_hash or
           internal_transaction.from_address_hash == ^balance.address_hash or
           internal_transaction.created_contract_address_hash == ^balance.address_hash)
    )
    |> select([internal_transaction], internal_transaction.transaction_hash)
    |> limit(1)
  end

  defp put_transaction_hash(hash, coin_balance),
    do: if(hash, do: %CoinBalance{coin_balance | transaction_hash: hash}, else: coin_balance)

  defp add_block_timestamp_to_balances(
         balances_raw_filtered,
         min_block_number,
         min_block_unix_timestamp,
         max_block_unix_timestamp,
         blocks_delta
       ) do
    balances_raw_filtered
    |> Enum.map(fn balance ->
      date =
        trunc(
          min_block_unix_timestamp +
            (balance.block_number - min_block_number) * (max_block_unix_timestamp - min_block_unix_timestamp) /
              blocks_delta
        )

      add_date_to_balance(balance, date)
    end)
  end

  defp add_min_block_timestamp_to_balances(balances_raw_filtered, min_block_unix_timestamp) do
    balances_raw_filtered
    |> Enum.map(fn balance ->
      date = min_block_unix_timestamp

      add_date_to_balance(balance, date)
    end)
  end

  defp add_date_to_balance(balance, date) do
    formatted_date = Timex.from_unix(date)
    %{balance | block_timestamp: formatted_date}
  end

  defp page_coin_balances(query, %PagingOptions{key: nil}), do: query

  defp page_coin_balances(query, %PagingOptions{key: {block_number}}) do
    where(query, [coin_balance], coin_balance.block_number < ^block_number)
  end

  defp find_block_timestamp(number, options) do
    Block
    |> where([block], block.number == ^number)
    |> select([block], block.timestamp)
    |> limit(1)
    |> Chain.select_repo(options).one()
  end

  defp fetch_coin_balance(address_hash, block_number) do
    coin_balance_subquery =
      from(
        cb in CoinBalance,
        where: cb.address_hash == ^address_hash,
        where: cb.block_number <= ^block_number,
        inner_join: b in Block,
        on: cb.block_number == b.number,
        limit: ^2,
        order_by: [desc: :block_number],
        select_merge: %{block_timestamp: b.timestamp}
      )

    from(
      cb in subquery(coin_balance_subquery),
      limit: ^1,
      order_by: [desc: :block_number],
      select_merge: %{delta: fragment("value - coalesce(lag(value, 1) over (order by block_number), 0)")}
    )
  end

  @doc false
  def fetch_coin_balances(address_hash, %PagingOptions{page_size: page_size}) do
    query =
      from(
        cb in CoinBalance,
        where: cb.address_hash == ^address_hash,
        where: not is_nil(cb.value),
        order_by: [desc: :block_number],
        select_merge: %{
          delta: fragment("? - coalesce(lead(?, 1) over (order by ? desc), 0)", cb.value, cb.value, cb.block_number)
        }
      )

    from(balance in subquery(query),
      where: balance.delta != 0,
      limit: ^page_size,
      select_merge: %{
        transaction_hash: nil
      }
    )
  end

  @doc false
  def balances_by_day(address_hash, block_timestamp \\ nil) do
    days_to_consider =
      Application.get_env(:block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance)[:coin_balance_history_days]

    CoinBalance
    |> join(:inner, [cb], block in Block, on: cb.block_number == block.number)
    |> where([cb], cb.address_hash == ^address_hash)
    |> limit_time_interval(days_to_consider, block_timestamp)
    |> group_by([cb, block], fragment("date_trunc('day', ?)", block.timestamp))
    |> order_by([cb, block], fragment("date_trunc('day', ?)", block.timestamp))
    |> select([cb, block], %{date: type(fragment("date_trunc('day', ?)", block.timestamp), :date), value: max(cb.value)})
  end

  defp limit_time_interval(query, days_to_consider, nil) do
    query
    |> where(
      [cb, block],
      block.timestamp >=
        fragment("date_trunc('day', now() - CAST(? AS INTERVAL))", ^%Postgrex.Interval{days: days_to_consider})
    )
  end

  defp limit_time_interval(query, days_to_consider, %{timestamp: timestamp}) do
    query
    |> where(
      [cb, block],
      block.timestamp >=
        fragment(
          "(? AT TIME ZONE ?) - CAST(? AS INTERVAL)",
          ^timestamp,
          ^"Etc/UTC",
          ^%Postgrex.Interval{days: days_to_consider}
        )
    )
  end

  defp add_coin_balances_fetcher_limit(query, false), do: query

  defp add_coin_balances_fetcher_limit(query, true) do
    coin_balances_fetcher_limit = Application.get_env(:indexer, :coin_balances_fetcher_init_limit)

    limit(query, ^coin_balances_fetcher_limit)
  end
end
