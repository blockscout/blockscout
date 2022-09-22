defmodule BlockScoutWeb.EpochTransactionView do
  use BlockScoutWeb, :view

  alias Explorer.Celo.EpochUtil
  alias Explorer.Chain.Wei

  def get_reward_currency(reward_type) do
    case reward_type do
      "voter" -> "CELO"
      _ -> "cUSD"
    end
  end

  def wei_to_ether_rounded(%Wei{value: value} = amount) do
    amount
    |> Wei.to(:ether)
    |> then(
      &Decimal.round(
        &1,
        cond do
          Decimal.cmp(value, Decimal.new(10_000_000_000_000)) == :lt -> 2
          Decimal.cmp(value, Decimal.new(100_000_000_000_000)) == :lt -> 5
          Decimal.cmp(value, Decimal.new(1_000_000_000_000_000)) == :lt -> 4
          Decimal.cmp(value, Decimal.new(10_000_000_000_000_000)) == :lt -> 3
          true -> 2
        end
      )
    )
  end
end
