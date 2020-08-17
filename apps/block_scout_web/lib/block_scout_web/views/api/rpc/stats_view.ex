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

  def render("ethprice.json", %{rates: rates}) do
    RPCView.render("show.json", data: prepare_rates(rates))
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_rates(rates) do
    timestamp = rates.last_updated |> DateTime.to_unix() |> to_string()

    %{
      "ethbtc" => to_string(rates.btc_value),
      "ethbtc_timestamp" => timestamp,
      "ethusd" => to_string(rates.usd_value),
      "ethusd_timestamp" => timestamp
    }
  end
end
