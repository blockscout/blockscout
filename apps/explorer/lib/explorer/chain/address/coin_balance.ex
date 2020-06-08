defmodule Explorer.Chain.Address.CoinBalance do
  @moduledoc """
  The `t:Explorer.Chain.Wei.t/0` `value` of `t:Explorer.Chain.Address.t/0` at the end of a `t:Explorer.Chain.Block.t/0`
  `t:Explorer.Chain.Block.block_number/0`.
  """

  use Explorer.Schema

  alias Explorer.PagingOptions
  alias Explorer.Chain.{Address, Block, Hash, Wei}
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
  @type t :: %__MODULE__{
          address: %Ecto.Association.NotLoaded{} | Address.t(),
          address_hash: Hash.Address.t(),
          block_number: Block.block_number(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t(),
          value: Wei.t() | nil
        }

  @primary_key false
  schema "address_coin_balances" do
    field(:block_number, :integer)
    field(:value, Wei)
    field(:value_fetched_at, :utc_datetime_usec)
    field(:delta, Wei, virtual: true)
    field(:block_timestamp, :utc_datetime_usec, virtual: true)

    timestamps()

    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)
  end

  @doc """
  Builds an `Ecto.Query` to fetch the coin balance of the given address in the given block.
  """
  def fetch_coin_balance(address_hash, block_number) do
    from(
      cb in CoinBalance,
      where: cb.address_hash == ^address_hash,
      where: cb.block_number <= ^block_number,
      inner_join: b in Block,
      on: cb.block_number == b.number,
      limit: ^1,
      order_by: [desc: :block_number],
      select_merge: %{delta: fragment("value - coalesce(lag(value, 1) over (order by block_number), 0)")},
      select_merge: %{block_timestamp: b.timestamp}
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch the last coin balances that have value greater than 0.

  The last coin balance from an Address is the last block indexed.
  """
  def fetch_coin_balances(address_hash, %PagingOptions{page_size: page_size}) do
    query =
      from(
        cb in CoinBalance,
        where: cb.address_hash == ^address_hash,
        where: not is_nil(cb.value),
        order_by: [desc: :block_number],
        select_merge: %{delta: fragment("value - coalesce(lead(value, 1) over (order by block_number desc), 0)")}
      )

    from(balance in subquery(query),
      where: balance.delta != 0,
      limit: ^page_size
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch a series of balances by day for the given account. Each element in the series
  corresponds to the maximum balance in that day. Only the last 90 days of data are used.
  """
  def balances_by_day(address_hash, block_timestamp \\ nil) do
    {days_to_consider, _} =
      Application.get_env(:block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance)[:coin_balance_history_days]
      |> Integer.parse()

    CoinBalance
    |> join(:inner, [cb], b in Block, on: cb.block_number == b.number)
    |> where([cb], cb.address_hash == ^address_hash)
    |> limit_time_interval(days_to_consider, block_timestamp)
    |> group_by([cb, b], fragment("date_trunc('day', ?)", b.timestamp))
    |> order_by([cb, b], fragment("date_trunc('day', ?)", b.timestamp))
    |> select([cb, b], %{date: type(fragment("date_trunc('day', ?)", b.timestamp), :date), value: max(cb.value)})
  end

  def limit_time_interval(query, days_to_consider, nil) do
    query
    |> where(
      [cb, b],
      b.timestamp >=
        fragment("date_trunc('day', now() - CAST(? AS INTERVAL))", ^%Postgrex.Interval{days: days_to_consider})
    )
  end

  def limit_time_interval(query, days_to_consider, %{timestamp: timestamp}) do
    query
    |> where(
      [cb, b],
      b.timestamp >=
        fragment(
          "(? AT TIME ZONE ?) - CAST(? AS INTERVAL)",
          ^timestamp,
          ^"Etc/UTC",
          ^%Postgrex.Interval{days: days_to_consider}
        )
    )
  end

  def last_coin_balance_timestamp(address_hash) do
    coin_balance_query =
      CoinBalance
      |> where([cb], cb.address_hash == ^address_hash)
      |> last(:block_number)
      |> select([cb, b], %{block_number: cb.block_number, value: cb.value})

    from(
      cb in subquery(coin_balance_query),
      inner_join: b in Block,
      on: cb.block_number == b.number,
      select: %{timestamp: b.timestamp, value: cb.value}
    )
  end

  def changeset(%__MODULE__{} = balance, params) do
    balance
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:address_hash)
    |> unique_constraint(:block_number, name: :address_coin_balances_address_hash_block_number_index)
  end
end
