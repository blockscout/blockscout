# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.RPC.TokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.BridgedTokensView
  alias Explorer.Chain.CurrencyHelper

  # Etherscan `tokeninfo` fields that Blockscout has no data source for.
  # They are always emitted as empty strings to keep the response shape
  # compatible with Etherscan.
  @empty_token_info_fields %{
    "description" => "",
    "website" => "",
    "email" => "",
    "blog" => "",
    "reddit" => "",
    "slack" => "",
    "facebook" => "",
    "twitter" => "",
    "bitcointalk" => "",
    "github" => "",
    "telegram" => "",
    "wechat" => "",
    "linkedin" => "",
    "discord" => "",
    "whitepaper" => ""
  }

  @token_price_usd_decimals 18

  def render("gettoken.json", %{token: token}) do
    RPCView.render("show.json", data: prepare_token(token))
  end

  def render("gettokenholders.json", %{token_holders: token_holders}) do
    data = Enum.map(token_holders, &prepare_token_holder/1)
    RPCView.render("show.json", data: data)
  end

  def render("tokenholderlist.json", %{token_holders: token_holders}) do
    data = Enum.map(token_holders, &prepare_etherscan_token_holder/1)
    RPCView.render("show.json", data: data)
  end

  def render("tokenholdercount.json", %{holder_count: holder_count}) do
    RPCView.render("show.json", data: prepare_holder_count(holder_count))
  end

  def render("tokeninfo.json", %{token: token}) do
    RPCView.render("show.json", data: [prepare_token_info(token)])
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

  defp prepare_etherscan_token_holder(token_holder) do
    %{
      "TokenHolderAddress" => to_string(token_holder.address_hash),
      "TokenHolderQuantity" => decimal_to_string(token_holder.value)
    }
  end

  defp prepare_holder_count(nil), do: "0"
  defp prepare_holder_count(count) when count < 0, do: "0"
  defp prepare_holder_count(count), do: to_string(count)

  defp prepare_token_info(token) do
    Map.merge(@empty_token_info_fields, %{
      "contractAddress" => to_string(token.contract_address_hash),
      "tokenName" => token.name || "",
      "symbol" => token.symbol || "",
      "divisor" => decimal_to_string(token.decimals),
      "tokenType" => String.replace(token.type, "-", ""),
      "totalSupply" => decimal_to_string(token.total_supply),
      "blueCheckmark" => to_string(token.is_verified_via_admin_panel == true),
      "tokenPriceUSD" => token_price_usd_to_string(token.fiat_value),
      "image" => token.icon_url || ""
    })
  end

  defp decimal_to_string(nil), do: ""
  defp decimal_to_string(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp decimal_to_string(value), do: to_string(value)

  defp token_price_usd_to_string(nil), do: token_price_usd_to_string(Decimal.new(0))

  defp token_price_usd_to_string(%Decimal{} = value) do
    value
    |> Decimal.round(@token_price_usd_decimals)
    |> Decimal.to_string(:normal)
  end

  defp token_price_usd_to_string(value) when is_float(value),
    do: value |> Decimal.from_float() |> token_price_usd_to_string()

  defp token_price_usd_to_string(value) when is_integer(value),
    do: value |> Decimal.new() |> token_price_usd_to_string()

  defp prepare_bridged_token({token, bridged_token}) do
    total_supply = CurrencyHelper.divide_decimals(token.total_supply, token.decimals)
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
