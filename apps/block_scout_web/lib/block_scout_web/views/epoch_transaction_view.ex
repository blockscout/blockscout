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

  def wei_to_ether_rounded(amount), do: amount |> Wei.to(:ether) |> then(&Decimal.round(&1, 2))
end
