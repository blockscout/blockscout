defmodule BlockScoutWeb.API.RPC.TokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.BridgedTokensView
  alias Explorer.Chain.CurrencyHelpers

  def render("gettoken.json", %{token: token}) do
    RPCView.render("show.json", data: prepare_token(token))
  end

  def render("gettokenholders.json", %{token_holders: token_holders}) do
    data = Enum.map(token_holders, &prepare_token_holder/1)
    RPCView.render("show.json", data: data)
  end

  def render("bridgedtokenlist.json", %{bridged_tokens: bridged_tokens}) do
    data = Enum.map(bridged_tokens, &prepare_bridged_token/1)
    RPCView.render("show.json", data: data)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_token(token) do
    %{
      "type" => token.type,
      "name" => token.name,
      "symbol" => token.symbol,
      "totalSupply" => to_string(token.total_supply),
      "decimals" => to_string(token.decimals),
      "contractAddress" => to_string(token.contract_address_hash),
      "cataloged" => token.cataloged
    }
  end

  defp prepare_token_holder(token_holder) do
    %{
      "address" => to_string(token_holder.address_hash),
      "value" => token_holder.value
    }
  end

  defp prepare_bridged_token([]) do
    %{}
  end

  defp prepare_bridged_token([token, bridged_token]) do
    total_supply = CurrencyHelpers.divide_decimals(token.total_supply, token.decimals)
    usd_value = BridgedTokensView.bridged_token_usd_cap(bridged_token, token)

    %{
      "foreignChainId" => bridged_token.foreign_chain_id,
      "foreignTokenContractAddressHash" => bridged_token.foreign_token_contract_address_hash,
      "homeContractAddressHash" => token.contract_address_hash,
      "homeDecimals" => token.decimals,
      "homeHolderCount" => if(token.holder_count, do: to_string(token.holder_count), else: "0"),
      "homeName" => token.name,
      "homeSymbol" => token.symbol,
      "homeTotalSupply" => total_supply,
      "homeUsdValue" => usd_value
    }
  end
end
