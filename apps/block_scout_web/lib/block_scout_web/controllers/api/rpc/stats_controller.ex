defmodule BlockScoutWeb.API.RPC.StatsController do
  use BlockScoutWeb, :controller

  use Explorer.Schema

  alias Explorer.{Chain, ExchangeRates}
  alias Explorer.Chain.Cache.{AddressSum, AddressSumMinusBurnt}
  alias Explorer.Chain.Wei

  def tokensupply(conn, params) do
    with {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- to_address_hash(contractaddress_param),
         {:token, {:ok, token}} <- {:token, Chain.token_from_address_hash(address_hash)} do
      render(conn, "tokensupply.json", token.total_supply)
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contractaddress is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid contractaddress format")

      {:token, {:error, :not_found}} ->
        render(conn, :error, error: "contractaddress not found")
    end
  end

  def ethsupplyexchange(conn, _params) do
    wei_total_supply =
      Chain.total_supply()
      |> Decimal.new()
      |> Wei.from(:ether)
      |> Wei.to(:wei)
      |> Decimal.to_string()

    render(conn, "ethsupplyexchange.json", total_supply: wei_total_supply)
  end

  def ethsupply(conn, _params) do
    cached_wei_total_supply = AddressSum.get_sum()

    render(conn, "ethsupply.json", total_supply: cached_wei_total_supply)
  end

  def coinsupply(conn, _params) do
    cached_coin_total_supply_wei = AddressSumMinusBurnt.get_sum_minus_burnt()

    cached_coin_total_supply =
      %Wei{value: Decimal.new(cached_coin_total_supply_wei)}
      |> Wei.to(:ether)

    render(conn, "coinsupply.json", cached_coin_total_supply)
  end

  def ethprice(conn, _params) do
    symbol = Application.get_env(:explorer, :coin)
    rates = ExchangeRates.lookup(symbol)

    render(conn, "ethprice.json", rates: rates)
  end

  defp fetch_contractaddress(params) do
    {:contractaddress_param, Map.fetch(params, "contractaddress")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end
end
