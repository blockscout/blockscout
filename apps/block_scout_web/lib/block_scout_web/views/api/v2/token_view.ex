defmodule BlockScoutWeb.API.V2.TokenView do
  def render("token.json", %{token: token}) do
    %{
      "address" => token.contract_address_hash,
      "symbol" => token.symbol,
      "name" => token.name,
      "decimals" => token.decimals,
      "type" => token.type,
      "holders" => to_string(token.holder_count),
      "exchange_rate" => token.usd_value && to_string(token.usd_value)
    }
  end
end
