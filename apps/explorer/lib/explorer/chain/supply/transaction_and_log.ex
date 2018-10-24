defmodule Explorer.Chain.Supply.TransactionAndLog do
  @moduledoc """
  Defines the supply API for calculating the supply for smaller chains with
  specific mint and burn events
  """
  use Explorer.Chain.Supply

  alias Explorer.Chain.{InternalTransaction, Log, Wei}
  alias Explorer.{Repo, Chain}

  {:ok, base_wei} = Wei.cast(0)
  @base_wei base_wei

  {:ok, burn_address} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")

  @burn_address burn_address
  @bridge_edge "0x3c798bbcf33115b42c728b8504cff11dd58736e9fa789f1cda2738db7d696b2a"

  import Ecto.Query, only: [from: 2]

  def circulating, do: total(Timex.now())

  def total, do: total(Timex.now())

  @doc false
  @spec total(DateTime.t()) :: %Decimal{sign: 1}
  def total(on_date) do
    on_date
    |> minted_value
    |> Wei.sub(burned_value(on_date))
    |> Wei.to(:ether)
  end

  def supply_for_days(days_count) when is_integer(days_count) and days_count > 0 do
    past_days = -(days_count - 1)

    result =
      for i <- past_days..0, into: %{} do
        datetime = Timex.shift(Timex.now(), days: i)
        {DateTime.to_date(datetime), total(datetime)}
      end

    {:ok, result}
  end

  defp minted_value(on_date) do
    query =
      from(
        l in Log,
        join: t in assoc(l, :transaction),
        join: b in assoc(t, :block),
        where: b.timestamp <= ^on_date and l.first_topic == @bridge_edge,
        select: fragment("concat('0x', encode(?, 'hex'))", l.data)
      )

    query
    |> Repo.all()
    |> Enum.reduce(@base_wei, fn data, acc ->
      {:ok, wei_value} = Wei.cast(data)
      Wei.sum(wei_value, acc)
    end)
  end

  defp burned_value(on_date) do
    query =
      from(
        it in InternalTransaction,
        join: t in assoc(it, :transaction),
        join: b in assoc(t, :block),
        where: b.timestamp <= ^on_date and it.to_address_hash == ^@burn_address,
        select: it.value
      )

    query
    |> Repo.all()
    |> Enum.reduce(@base_wei, fn data, acc -> Wei.sum(data, acc) end)
  end
end
