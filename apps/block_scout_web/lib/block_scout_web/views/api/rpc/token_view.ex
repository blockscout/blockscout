defmodule BlockScoutWeb.API.RPC.TokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("gettoken.json", %{token_detail: token_detail}) do
    RPCView.render("show.json", data: prepare_token(token_detail))
  end

  def render("getlisttokentransfers.json", %{
    token_transfers: token_transfers, has_next_page: has_next_page, next_page_path: next_page_path}) do
    data = %{
      "result" => Enum.map(token_transfers, &prepare_token_transfer/1),
      "hasNextPage" => has_next_page,
      "nextPagePath" => next_page_path
    }
    RPCView.render("show_data.json", data: data)
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

  defp prepare_token(token_detail) do
    %{
      "type" => token_detail.token.type,
      "name" => token_detail.token.name,
      "symbol" => token_detail.token.symbol,
      "totalSupply" => to_string(token_detail.token.total_supply),
      "decimals" => to_string(token_detail.token.decimals),
      "contractAddress" => to_string(token_detail.token.contract_address_hash),
      "cataloged" => token_detail.token.cataloged,
      "transfersCount" => token_detail.transfers_count,
      "holdersCount" => token_detail.holders_count
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

  defp prepare_token_transfer(token_transfer) do
    %{
      "blockNumber" => to_string(token_transfer.block_number),
      "transactionHash" => "#{token_transfer.transaction.hash}",
      "blockHash" => "#{token_transfer.transaction.block.hash}",
      "timestamp" => to_string(DateTime.to_unix(token_transfer.transaction.block.timestamp)),
      "amount" => "#{token_transfer.amount}",
      "fromAddress" => "#{token_transfer.from_address}",
      "fromAddressName" => prepare_address_name(token_transfer.from_address),
      "toAddress" => "#{token_transfer.to_address}",
      "toAddressName" => prepare_address_name(token_transfer.to_address),
      "tokenContractAddress" => "#{token_transfer.token_contract_address}",
      "tokenName" => "#{token_transfer.token.name}",
      "tokenSymbol" => "#{token_transfer.token.symbol}",
      "decimals" => "#{token_transfer.token.decimals}"
    }
  end

  defp prepare_address_name(address) do
    case address do
      nil ->
        ""
      _ ->
        case address.names do
          [_|_] ->
            Enum.at(address.names, 0).name
          _ ->
            ""
        end
    end
  end
end
