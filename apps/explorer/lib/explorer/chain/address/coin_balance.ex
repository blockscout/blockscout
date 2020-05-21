# credo:disable-for-this-file
defmodule Explorer.Chain.Address.CoinBalance do
  @moduledoc """
  The `t:Explorer.Chain.Wei.t/0` `value` of `t:Explorer.Chain.Address.t/0` at the end of a `t:Explorer.Chain.Block.t/0`
  `t:Explorer.Chain.Block.block_number/0`.
  """

  use Explorer.Schema

  alias Explorer.{PagingOptions, Repo}
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
    from(
      cb in CoinBalance,
      where: cb.address_hash == ^address_hash,
      where: not is_nil(cb.value),
      inner_join: b in Block,
      on: cb.block_number == b.number,
      order_by: [desc: :block_number],
      limit: ^page_size,
      select_merge: %{delta: fragment("value - coalesce(lag(value, 1) over (order by block_number), 0)")},
      select_merge: %{block_timestamp: b.timestamp}
    )
  end

  @doc """
  Builds an `Ecto.Query` to fetch a series of balances by day for the given account. Each element in the series
  corresponds to the maximum balance in that day. Only the last `n` days of data are used.
  `n` is configurable via COIN_BALANCE_HISTORY_DAYS ENV var.
  """
  def balances_by_day(address_hash) do
    days_to_consider =
      Application.get_env(:block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance)[:coin_balance_history_days]

    {days_to_consider, _} = Integer.parse(days_to_consider)
    now = Timex.now()

    target_block_number_query =
      Block
      |> where(
        [b],
        b.timestamp >=
          fragment("date_trunc('day', now() - CAST(? AS INTERVAL))", ^%Postgrex.Interval{days: days_to_consider})
      )
      |> where(
        [b],
        fragment("date_trunc('day', ?)", b.timestamp) ==
          ^Timex.beginning_of_day(Timex.shift(now, days: -(days_to_consider - 1)))
      )
      |> limit(1)
      |> select([b], %{block_number: b.number, block_timestamp: b.timestamp})

    result =
      target_block_number_query
      |> Repo.one()

    min_block_number_target =
      if result do
        %{block_number: min_block_number_target, block_timestamp: _} = result
        min_block_number_target
      else
        0
      end

    balances =
      CoinBalance
      |> where([cb], cb.address_hash == ^address_hash)
      |> where([cb], cb.block_number >= ^min_block_number_target)
      |> select([cb], %{block: cb.block_number, value: cb.value})
      |> Repo.all()

    if Enum.empty?(balances) do
      []
    else
      [%{block: max_block_number, value: _value}] =
        balances
        |> Enum.sort(&(&1.block <= &2.block))
        |> Enum.take(-1)

      [%{block: min_block_number, value: _value}] =
        balances
        |> Enum.sort(&(&1.block <= &2.block))
        |> Enum.take(1)

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
          balances
          |> Enum.map(fn balance ->
            date =
              trunc(
                min_block_unix_timestamp +
                  (balance.block - min_block_number) * (max_block_unix_timestamp - min_block_unix_timestamp) /
                    blocks_delta
              )

            {:ok, formatted_date} = Timex.format(Timex.from_unix(date), "{YYYY}-{0M}-{0D}")
            %{date: formatted_date, value: balance.value}
          end)
        else
          balances
          |> Enum.map(fn balance ->
            date = min_block_unix_timestamp

            {:ok, formatted_date} = Timex.format(Timex.from_unix(date), "{YYYY}-{0M}-{0D}")
            %{date: formatted_date, value: balance.value}
          end)
        end
        |> Enum.filter(fn balance -> balance.value end)
        |> Enum.sort(fn balance1, balance2 -> balance1.date <= balance2.date end)

      balances_with_dates_grouped =
        balances_with_dates
        |> Enum.reduce([], fn balance, acc ->
          if Enum.empty?(acc) do
            acc ++ [balance]
          else
            [current_last_balance] = Enum.take(acc, -1)

            if Map.get(current_last_balance, :date) == Map.get(balance, :date) do
              acc =
                if Map.get(current_last_balance, :value) < Map.get(balance, :value) do
                  acc = Enum.drop(acc, -1)
                  acc ++ [balance]
                else
                  acc
                end

              acc
            else
              acc ++ [balance]
            end
          end
        end)

      balances_with_dates_grouped
    end
  end

  defp find_block_timestamp(number) do
    Block
    |> where([b], b.number == ^number)
    |> select([b], b.timestamp)
    |> Repo.one()
  end

  def last_coin_balance_timestamp(address_hash) do
    CoinBalance
    |> join(:inner, [cb], b in Block, on: cb.block_number == b.number)
    |> where([cb], cb.address_hash == ^address_hash)
    |> last(:block_number)
    |> select([cb, b], %{timestamp: b.timestamp, value: cb.value})
  end

  def changeset(%__MODULE__{} = balance, params) do
    balance
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:address_hash)
    |> unique_constraint(:block_number, name: :address_coin_balances_address_hash_block_number_index)
  end
end
