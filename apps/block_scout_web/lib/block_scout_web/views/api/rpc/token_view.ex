defmodule BlockScoutWeb.API.RPC.TokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias BlockScoutWeb.BridgedTokensView

  def render("gettoken.json", %{token: token}) do
    RPCView.render("show.json", data: prepare_token(token))
  end

  def render("tokentx.json", %{token_transfers: token_transfers}) do
    data = Enum.map(token_transfers, &prepare_token_transfer/1)
    RPCView.render("show.json", data: data)
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

  defp prepare_token_transfer(token_transfer) do
    %{
      "amount" => "#{token_transfer.amount}",
      "fromAddressHash" => "#{token_transfer.from_address_hash}",
      "toAddressHash" => "#{token_transfer.to_address_hash}",
      "blockNumber" => integer_to_hex(token_transfer.block_number),
      "timeStamp" => datetime_to_hex(token_transfer.block_timestamp),
      "transactionHash" => "#{token_transfer.transaction_hash}",
      "address" => "#{token_transfer.token_contract_address_hash}",
      "transactionIndex" => integer_to_hex(token_transfer.transaction_index),
      "logIndex" => integer_to_hex(token_transfer.log_index),
      "gasPrice" => decimal_to_hex(token_transfer.gas_price.value),
      "gasUsed" => decimal_to_hex(token_transfer.gas_used),
      "feeCurrency" => "#{token_transfer.gas_currency_hash}",
      "gatewayFeeRecipient" => "#{token_transfer.gas_fee_recipient_hash}",
      "gatewayFee" => "#{token_transfer.gateway_fee}",
      "topics" => get_topics(token_transfer),
      "data" => "#{token_transfer.data}"
    }
  end

  defp integer_to_hex(nil), do: ""
  defp integer_to_hex(integer), do: Integer.to_string(integer, 16)

  defp decimal_to_hex(decimal) do
    decimal
    |> Decimal.to_integer()
    |> integer_to_hex()
  end

  defp datetime_to_hex(datetime) do
    datetime
    |> DateTime.to_unix()
    |> integer_to_hex()
  end

  defp get_topics(%{
         first_topic: first_topic,
         second_topic: second_topic,
         third_topic: third_topic,
         fourth_topic: fourth_topic
       }) do
    [first_topic, second_topic, third_topic, fourth_topic]
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
    total_supply = divide_decimals(token.total_supply, token.decimals)
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
