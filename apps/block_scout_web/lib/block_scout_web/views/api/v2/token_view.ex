defmodule BlockScoutWeb.API.V2.TokenView do
  alias BlockScoutWeb.API.V2.Helper
  alias Explorer.Chain.Address

  def render("token.json", %{token: token}) do
    %{
      "address" => Address.checksum(token.contract_address_hash),
      "symbol" => token.symbol,
      "name" => token.name,
      "decimals" => token.decimals,
      "type" => token.type,
      "holders" => token.holder_count && to_string(token.holder_count),
      "exchange_rate" => exchange_rate(token),
      "total_supply" => token.total_supply
    }
  end

  def render("token_balances.json", %{
        token_balances: token_balances,
        next_page_params: next_page_params,
        conn: conn,
        token: token
      }) do
    %{
      "items" => Enum.map(token_balances, &prepare_token_balance(&1, conn, token)),
      "next_page_params" => next_page_params
    }
  end

  def exchange_rate(%{usd_value: usd_value}) when not is_nil(usd_value), do: to_string(usd_value)
  def exchange_rate(_), do: nil

  def prepare_token_balance(token_balance, conn, token) do
    %{
      "address" => Helper.address_with_info(conn, token_balance.address, token_balance.address_hash),
      "value" => token_balance.value,
      "token_id" => token_balance.token_id,
      "token" => render("token.json", %{token: token})
    }
  end
end
