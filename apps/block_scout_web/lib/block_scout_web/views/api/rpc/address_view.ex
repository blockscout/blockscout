defmodule BlockScoutWeb.API.RPC.AddressView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("balance.json", %{addresses: [address]}) do
    RPCView.render("show.json", data: "#{address.fetched_balance.value}")
  end

  def render("balance.json", assigns) do
    render("balancemulti.json", assigns)
  end

  def render("balancemulti.json", %{addresses: addresses}) do
    data =
      Enum.map(addresses, fn address ->
        %{
          "account" => "#{address.hash}",
          "balance" => "#{address.fetched_balance.value}"
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
end
