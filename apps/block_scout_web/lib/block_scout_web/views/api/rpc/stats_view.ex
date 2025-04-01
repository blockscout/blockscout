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
    RPCView.render("show.json", data: prepare_rates(rates, "eth"))
  end

  def render("coinprice.json", %{rates: rates}) do
    RPCView.render("show.json", data: prepare_rates(rates, "coin_"))
  end

  def render("totalfees.json", %{total_fees: total_fees}) do
    RPCView.render("show.json", data: total_fees)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_rates(rates, prefix) do
    if rates do
      timestamp = rates.last_updated && rates.last_updated |> DateTime.to_unix() |> to_string()

      %{
        (prefix <> "btc") => rates.btc_value && to_string(rates.btc_value),
        (prefix <> "btc_timestamp") => timestamp,
        (prefix <> "usd") => rates.fiat_value && to_string(rates.fiat_value),
        (prefix <> "usd_timestamp") => timestamp
      }
    else
      %{
        (prefix <> "btc") => nil,
        (prefix <> "btc_timestamp") => nil,
        (prefix <> "usd") => nil,
        (prefix <> "usd_timestamp") => nil
      }
    end
  end
end
