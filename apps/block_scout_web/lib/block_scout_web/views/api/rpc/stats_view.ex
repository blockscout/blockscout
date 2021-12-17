defmodule BlockScoutWeb.API.RPC.StatsView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("tokensupply.json", %{total_supply: token_supply}) do
    RPCView.render("show.json", data: token_supply)
  end

  def render("ethsupplyexchange.json", %{total_supply: total_supply}) do
    RPCView.render("show.json", data: total_supply)
  end

  def render("ethsupply.json", %{total_supply: total_supply}) do
    RPCView.render("show.json", data: total_supply)
  end

  def render("coinsupply.json", %{total_supply: total_supply}) do
    RPCView.render("show_value.json", data: total_supply)
  end

  def render("coinprice.json", %{rates: rates}) do
    RPCView.render("show.json", data: prepare_rates(rates))
  end

  def render("totaltransactions.json", %{count: count}) do
    RPCView.render("show.json", data: count)
  end

  def render("celounlocked.json", %{celo_unlocked: celo_unlocked}) do
    data = Enum.map(celo_unlocked, &prepare_celo_unlocked/1)
    RPCView.render("show.json", data: data)
  end

  def render("totalfees.json", %{total_fees: total_fees}) do
    RPCView.render("show.json", data: total_fees)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_rates(rates) do
    if rates do
      timestamp = rates.last_updated |> DateTime.to_unix() |> to_string()

      %{
        "coin_btc" => to_string(rates.btc_value),
        "coin_btc_timestamp" => timestamp,
        "coin_usd" => to_string(rates.usd_value),
        "coin_usd_timestamp" => timestamp
      }
    else
      %{
        "coin_btc" => nil,
        "coin_btc_timestamp" => nil,
        "coin_usd" => nil,
        "coin_usd_timestamp" => nil
      }
    end
  end

  defp prepare_celo_unlocked(celo_unlocked) do
    %{
      "total" => celo_unlocked.total,
      "availableForWithdrawal" => celo_unlocked.available_for_withdrawal
    }
  end
end
