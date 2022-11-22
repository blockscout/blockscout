defmodule BlockScoutWeb.API.V2.TokenView do
  alias Explorer.Chain.Address

  def render("token.json", %{token: token}) do
    %{
      "address" => Address.checksum(token.contract_address_hash),
      "symbol" => token.symbol,
      "name" => token.name,
      "decimals" => token.decimals,
      "type" => token.type,
      "holders" => token.holder_count && to_string(token.holder_count),
      "exchange_rate" => token.usd_value && to_string(token.usd_value)
    }
  end
end
