defmodule BlockScoutWeb.StakesHelpers do
  @moduledoc """
  Helpers for staking templates
  """
  alias Explorer.Chain.Cache.BlockNumber
  alias Timex.Duration

  def amount_ratio(pool) do
    zero = Decimal.new(0)

    case pool do
      %{staked_amount: ^zero} ->
        0

      %{staked_amount: staked_amount, self_staked_amount: self_staked} ->
        amount = Decimal.to_float(staked_amount)
        self = Decimal.to_float(self_staked)
        self / amount * 100
    end
  end

  def estimated_unban_day(banned_until, average_block_time) do
    block_time = Duration.to_seconds(average_block_time)

    try do
      during_sec = (banned_until - BlockNumber.get_max()) * block_time
      now = DateTime.utc_now() |> DateTime.to_unix()
      date = DateTime.from_unix!(trunc(now + during_sec))
      Timex.format!(date, "%d %b %Y", :strftime)
    rescue
      _e ->
        DateTime.utc_now()
        |> Timex.format!("%d %b %Y", :strftime)
    end
  end

  def list_title(:validator), do: "Validators"
  def list_title(:active), do: "Active Pools"
  def list_title(:inactive), do: "Inactive Pools"
end
