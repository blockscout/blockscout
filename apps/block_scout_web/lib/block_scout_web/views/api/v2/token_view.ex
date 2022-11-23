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
      "exchange_rate" => exchange_rate(token)
    }
  end

  def exchange_rate(%{usd_value: usd_value}) when not is_nil(usd_value), do: to_string(usd_value)
  def exchange_rate(_), do: nil
end
