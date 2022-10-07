defmodule BlockScoutWeb.API.RPC.TokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("gettoken.json", %{token: token}) do
    RPCView.render("show.json", data: prepare_token(token))
  end

  def render("gettokenholders.json", %{token_holders: token_holders, hasNextPage: hasNextPage}) do
    data = %{
      "result" => Enum.map(token_holders, &prepare_token_holder/1),
      "hasNextPage" => hasNextPage
    }
    RPCView.render("show_data.json", data: data)
  end

  def render("getlisttokens.json", %{list_tokens: tokens, hasNextPage: hasNextPage}) do
    data = %{
      "result" => Enum.map(tokens, &prepare_list_tokens/1),
      "hasNextPage" => hasNextPage
    }
    RPCView.render("show_data.json", data: data)
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

  defp prepare_list_tokens(token) do
    %{
      "cataloged" => token.cataloged,
      "contractAddressHash" => to_string(token.contract_address_hash),
      "decimals" => to_string(token.decimals),
      "holderCount" => token.holder_count,
      "name" => token.name,
      "symbol" => token.symbol,
      "totalSupply" => to_string(token.total_supply),
      "type" => token.type
    }
  end

  defp prepare_token_holder(token_holder) do
    %{
      "address" => to_string(token_holder.address_hash),
      "value" => token_holder.value
    }
  end
end
