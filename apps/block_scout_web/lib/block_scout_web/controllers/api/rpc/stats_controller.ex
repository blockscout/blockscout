defmodule BlockScoutWeb.API.RPC.StatsController do
  use BlockScoutWeb, :controller

  use Explorer.Schema

  alias Explorer.{Chain, Etherscan, ExchangeRates}
  alias Explorer.Chain.Cache.{AddressSum, AddressSumMinusBurnt}
  alias Explorer.Chain.Wei

  def tokensupply(conn, params) do
    with {:contractaddress_param, {:ok, contractaddress_param}} <- fetch_contractaddress(params),
         {:format, {:ok, address_hash}} <- to_address_hash(contractaddress_param),
         {:token, {:ok, token}} <- {:token, Chain.token_from_address_hash(address_hash)} do
      case Map.get(params, "cmc", nil) do
        nil ->
          render(conn, "tokensupply.json", total_supply: Decimal.to_string(token.total_supply))

        _ ->
          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(200, Decimal.to_string(token.total_supply))
      end
    else
      {:contractaddress_param, :error} ->
        render(conn, :error, error: "Query parameter contract address is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid contract address format")

      {:token, {:error, :not_found}} ->
        render(conn, :error, error: "contract address not found")
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

    coin_total_supply_wei =
      if Decimal.compare(cached_coin_total_supply_wei, 0) == :gt do
        cached_coin_total_supply_wei
      else
        Chain.get_last_fetched_counter("sum_coin_total_supply_minus_burnt")
      end

    cached_coin_total_supply =
      %Wei{value: Decimal.new(coin_total_supply_wei)}
      |> Wei.to(:ether)
      |> Decimal.to_string(:normal)

    render(conn, "coinsupply.json", total_supply: cached_coin_total_supply)
  end

  def coinprice(conn, _params) do
    symbol = Application.get_env(:explorer, :coin)
    rates = ExchangeRates.lookup(symbol)

    render(conn, "coinprice.json", rates: rates)
  end

  def totaltransactions(conn, _params) do
    transaction_estimated_count = Chain.transaction_estimated_count()
    render(conn, "totaltransactions.json", count: transaction_estimated_count)
  end

  def celounlocked(conn, _params) do
    %Wei{value: sum_celo_unlocked} = Chain.fetch_sum_celo_unlocked()
    %Wei{value: sum_available_celo_unlocked} = Chain.fetch_sum_available_celo_unlocked()

    render(conn, "celounlocked.json",
      celo_unlocked: [
        %{
          total: Decimal.to_string(sum_celo_unlocked),
          available_for_withdrawal: Decimal.to_string(sum_available_celo_unlocked)
        }
      ]
    )
  end

  defp fetch_contractaddress(params) do
    {:contractaddress_param, Map.fetch(params, "contractaddress")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end

  def totalfees(conn, params) do
    case Map.fetch(params, "date") do
      {:ok, date} ->
        case Etherscan.get_total_fees_per_day(date) do
          {:ok, total_fees} -> render(conn, "totalfees.json", total_fees: total_fees)
          {:error, error} -> render(conn, :error, error: error)
        end

      _ ->
        render(conn, :error, error: "Required date input is missing.")
    end
  end
end
