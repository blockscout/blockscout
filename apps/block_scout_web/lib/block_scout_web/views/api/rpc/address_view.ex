defmodule BlockScoutWeb.API.RPC.AddressView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("balance.json", %{addresses: [address]}) do
    RPCView.render("show.json", data: "#{address.fetched_coin_balance.value}")
  end

  def render("balance.json", assigns) do
    render("balancemulti.json", assigns)
  end

  def render("balancemulti.json", %{addresses: addresses}) do
    data =
      Enum.map(addresses, fn address ->
        %{
          "account" => "#{address.hash}",
          "balance" => "#{address.fetched_coin_balance.value}"
        }
      end)

    RPCView.render("show.json", data: data)
  end

  def render("txlist.json", %{transactions: transactions}) do
    data = Enum.map(transactions, &prepare_transaction/1)
    RPCView.render("show.json", data: data)
  end

  def render("txlistinternal.json", %{internal_transactions: internal_transactions}) do
    data = Enum.map(internal_transactions, &prepare_internal_transaction/1)
    RPCView.render("show.json", data: data)
  end

  def render("tokentx.json", %{token_transfers: token_transfers}) do
    data = Enum.map(token_transfers, &prepare_token_transfer/1)
    RPCView.render("show.json", data: data)
  end

  def render("tokenbalance.json", %{token_balance: token_balance}) do
    RPCView.render("show.json", data: to_string(token_balance))
  end

  def render("token_list.json", %{token_list: token_list}) do
    data = Enum.map(token_list, &prepare_token/1)
    RPCView.render("show.json", data: data)
  end

  def render("getminedblocks.json", %{blocks: blocks}) do
    data = Enum.map(blocks, &prepare_block/1)
    RPCView.render("show.json", data: data)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_transaction(transaction) do
    %{
      "blockNumber" => "#{transaction.block_number}",
      "timeStamp" => "#{DateTime.to_unix(transaction.block_timestamp)}",
      "hash" => "#{transaction.hash}",
      "nonce" => "#{transaction.nonce}",
      "blockHash" => "#{transaction.block_hash}",
      "transactionIndex" => "#{transaction.index}",
      "from" => "#{transaction.from_address_hash}",
      "to" => "#{transaction.to_address_hash}",
      "value" => "#{transaction.value.value}",
      "gas" => "#{transaction.gas}",
      "gasPrice" => "#{transaction.gas_price.value}",
      "isError" => if(transaction.status == :ok, do: "0", else: "1"),
      "txreceipt_status" => if(transaction.status == :ok, do: "1", else: "0"),
      "input" => "#{transaction.input}",
      "contractAddress" => "#{transaction.created_contract_address_hash}",
      "cumulativeGasUsed" => "#{transaction.cumulative_gas_used}",
      "gasUsed" => "#{transaction.gas_used}",
      "confirmations" => "#{transaction.confirmations}"
    }
  end

  defp prepare_internal_transaction(internal_transaction) do
    %{
      "blockNumber" => "#{internal_transaction.block_number}",
      "timeStamp" => "#{DateTime.to_unix(internal_transaction.block_timestamp)}",
      "from" => "#{internal_transaction.from_address_hash}",
      "to" => "#{internal_transaction.to_address_hash}",
      "value" => "#{internal_transaction.value.value}",
      "contractAddress" => "#{internal_transaction.created_contract_address_hash}",
      "input" => "#{internal_transaction.input}",
      "type" => "#{internal_transaction.type}",
      "gas" => "#{internal_transaction.gas}",
      "gasUsed" => "#{internal_transaction.gas_used}",
      "isError" => if(internal_transaction.error, do: "1", else: "0"),
      "errCode" => "#{internal_transaction.error}"
    }
  end

  defp prepare_token_transfer(token_transfer) do
    %{
      "blockNumber" => to_string(token_transfer.block_number),
      "timeStamp" => to_string(DateTime.to_unix(token_transfer.block_timestamp)),
      "hash" => to_string(token_transfer.transaction_hash),
      "nonce" => to_string(token_transfer.transaction_nonce),
      "blockHash" => to_string(token_transfer.block_hash),
      "from" => to_string(token_transfer.from_address_hash),
      "contractAddress" => to_string(token_transfer.token_contract_address_hash),
      "to" => to_string(token_transfer.to_address_hash),
      "value" => to_string(token_transfer.amount),
      "tokenName" => token_transfer.token_name,
      "tokenSymbol" => token_transfer.token_symbol,
      "tokenDecimal" => to_string(token_transfer.token_decimals),
      "transactionIndex" => to_string(token_transfer.transaction_index),
      "gas" => to_string(token_transfer.transaction_gas),
      "gasPrice" => to_string(token_transfer.transaction_gas_price.value),
      "gasUsed" => to_string(token_transfer.transaction_gas_used),
      "cumulativeGasUsed" => to_string(token_transfer.transaction_cumulative_gas_used),
      "input" => to_string(token_transfer.transaction_input),
      "confirmations" => to_string(token_transfer.confirmations)
    }
  end

  defp prepare_block(block) do
    %{
      "blockNumber" => to_string(block.number),
      "timeStamp" => to_string(block.timestamp),
      "blockReward" => to_string(block.reward.value)
    }
  end

  defp prepare_token(token) do
    %{
      "balance" => to_string(token.balance),
      "contractAddress" => to_string(token.contract_address_hash),
      "name" => token.name,
      "decimals" => to_string(token.decimals),
      "symbol" => token.symbol
    }
  end
end
