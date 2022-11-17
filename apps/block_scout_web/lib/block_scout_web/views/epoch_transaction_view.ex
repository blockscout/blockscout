defmodule BlockScoutWeb.EpochTransactionView do
  use BlockScoutWeb, :view

  alias Explorer.Celo.EpochUtil
  alias Explorer.Chain
  alias Explorer.Chain.Wei

  @visible_rewards_batch_size 20

  def get_reward_currency(reward_type) do
    case reward_type do
      "voter" -> "CELO"
      _ -> "cUSD"
    end
  end

  def get_reward_currency_address_hash(reward_type) do
    reward_type |> EpochUtil.get_reward_currency_address_hash()
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

  def separate_visible_rewards(rewards) when is_list(rewards) do
    rewards |> Enum.split(@visible_rewards_batch_size)
  end

  def get_total_reward_value(nil), do: %Wei{value: Decimal.new(0)}
  def get_total_reward_value(%{amount: amount}), do: amount
end
