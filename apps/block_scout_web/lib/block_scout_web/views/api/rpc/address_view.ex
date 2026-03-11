defmodule BlockScoutWeb.API.RPC.AddressView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.EthRPC.View, as: EthRPCView
  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.Chain.{DenormalizationHelper, InternalTransaction, Transaction}

  def render("listaccounts.json", %{accounts: accounts}) do
    accounts = Enum.map(accounts, &prepare_account/1)
    RPCView.render("show.json", data: accounts)
  end

  def render("balance.json", %{addresses: [address]}) do
    RPCView.render("show.json", data: balance(address))
  end

  def render("balance.json", assigns) do
    render("balancemulti.json", assigns)
  end

  def render("balancemulti.json", %{addresses: addresses}) do
    data = Enum.map(addresses, &render_address/1)

    RPCView.render("show.json", data: data)
  end

  def render("pendingtxlist.json", %{transactions: transactions}) do
    data = Enum.map(transactions, &prepare_pending_transaction/1)
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

  def render("tokentx.json", %{token_transfers: token_transfers, max_block_number: max_block_number}) do
    transactions = token_transfers |> Enum.map(& &1.transaction) |> Transaction.decode_transactions(true, api?: true)

    data =
      token_transfers
      |> Enum.zip(transactions)
      |> Enum.map(fn {token_transfer, decoded_input} ->
        prepare_token_transfer(token_transfer, max_block_number, decoded_input)
      end)

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

  def render("eth_get_balance.json", %{balance: balance}) do
    EthRPCView.render("show.json", %{result: balance, id: 0})
  end

  def render("eth_get_balance_error.json", %{error: message}) do
    EthRPCView.render("error.json", %{error: message, id: 0})
  end

  def render("pending_internal_transaction.json", %{data: data} = assigns) do
    prepared_internal_transactions = Enum.map(data, &prepare_internal_transaction/1)
    RPCView.render("pending_internal_transaction.json", Map.put(assigns, :data, prepared_internal_transactions))
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp render_address(address) do
    %{
      "account" => "#{address.hash}",
      "balance" => balance(address),
      "stale" => address.stale? || false
    }
  end

  defp prepare_account(address) do
    %{
      "balance" => to_string(address.fetched_coin_balance && address.fetched_coin_balance.value),
      "address" => to_string(address.hash),
      "stale" => address.stale? || false
    }
  end

  defp prepare_pending_transaction(transaction) do
    %{
      "hash" => "#{transaction.hash}",
      "nonce" => "#{transaction.nonce}",
      "from" => "#{transaction.from_address_hash}",
      "to" => "#{transaction.to_address_hash}",
      "value" => "#{transaction.value.value}",
      "gas" => "#{transaction.gas}",
      "gasPrice" => "#{transaction.gas_price.value}",
      "input" => "#{transaction.input}",
      "contractAddress" => "#{transaction.created_contract_address_hash}",
      "cumulativeGasUsed" => "#{transaction.cumulative_gas_used}",
      "gasUsed" => "#{transaction.gas_used}"
    }
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
      "gasPrice" => "#{transaction.gas_price && transaction.gas_price.value}",
      "isError" => if(transaction.status == :ok, do: "0", else: "1"),
      "txreceipt_status" => if(transaction.status == :ok, do: "1", else: "0"),
      "input" => "#{transaction.input}",
      "contractAddress" => "#{transaction.created_contract_address_hash}",
      "cumulativeGasUsed" => "#{transaction.cumulative_gas_used}",
      "gasUsed" => "#{transaction.gas_used}",
      "confirmations" => "#{transaction.confirmations}",
      "methodId" => Transaction.method_id(transaction)
    }
  end

  # Prepares an internal transaction for API response.
  @spec prepare_internal_transaction(InternalTransaction.t()) :: map()
  defp prepare_internal_transaction(internal_transaction) do
    %{
      "blockNumber" => "#{internal_transaction.block_number}",
      "timeStamp" => "#{DateTime.to_unix(internal_transaction.block_timestamp)}",
      "from" => "#{internal_transaction.from_address_hash}",
      "to" => "#{internal_transaction.to_address_hash}",
      "value" => "#{(internal_transaction.value && internal_transaction.value.value) || 0}",
      "contractAddress" => "#{internal_transaction.created_contract_address_hash}",
      "transactionHash" => to_string(internal_transaction.transaction_hash),
      "index" => to_string(internal_transaction.index),
      "input" => "#{internal_transaction.input}",
      "type" => "#{internal_transaction.type}",
      "callType" => "#{InternalTransaction.call_type(internal_transaction)}",
      "gas" => to_string(internal_transaction.gas || 0),
      "gasUsed" => "#{internal_transaction.gas_used}",
      "isError" => if(internal_transaction.error, do: "1", else: "0"),
      "errCode" => "#{internal_transaction.error}"
    }
  end

  defp prepare_common_token_transfer(token_transfer, max_block_number, decoded_input) do
    tt_denormalization_fields =
      if DenormalizationHelper.tt_denormalization_finished?() do
        %{
          "timeStamp" =>
            if(token_transfer.transaction.block_timestamp,
              do: to_string(DateTime.to_unix(token_transfer.transaction.block_timestamp)),
              else: ""
            )
        }
      else
        %{
          "timeStamp" =>
            if(token_transfer.block.timestamp,
              do: to_string(DateTime.to_unix(token_transfer.block.timestamp)),
              else: ""
            )
        }
      end

    %{
      "blockNumber" => to_string(token_transfer.block_number),
      "hash" => to_string(token_transfer.transaction_hash),
      "nonce" => to_string(token_transfer.transaction.nonce),
      "blockHash" => to_string(token_transfer.block_hash),
      "from" => to_string(token_transfer.from_address_hash),
      "contractAddress" => to_string(token_transfer.token_contract_address_hash),
      "to" => to_string(token_transfer.to_address_hash),
      "tokenName" => token_transfer.token.name,
      "tokenSymbol" => token_transfer.token.symbol,
      "tokenDecimal" => to_string(token_transfer.token.decimals),
      "transactionIndex" => to_string(token_transfer.transaction.index),
      "gas" => to_string(token_transfer.transaction.gas),
      "gasPrice" => to_string(token_transfer.transaction.gas_price && token_transfer.transaction.gas_price.value),
      "gasUsed" => to_string(token_transfer.transaction.gas_used),
      "cumulativeGasUsed" => to_string(token_transfer.transaction.cumulative_gas_used),
      "input" => to_string(token_transfer.transaction.input),
      "confirmations" => to_string(max_block_number - token_transfer.block_number)
    }
    |> Map.merge(tt_denormalization_fields)
    |> Map.merge(prepare_decoded_input(decoded_input))
  end

  defp prepare_token_transfer(%{token_type: "ERC-721"} = token_transfer, max_block_number, decoded_input) do
    token_transfer
    |> prepare_common_token_transfer(max_block_number, decoded_input)
    |> Map.put_new(:tokenID, List.first(token_transfer.token_ids))
  end

  defp prepare_token_transfer(%{token_type: "ERC-1155"} = token_transfer, max_block_number, decoded_input) do
    token_transfer
    |> prepare_common_token_transfer(max_block_number, decoded_input)
    |> Map.put_new(:tokenID, token_transfer.token_id)
    |> Map.put_new(:tokenValue, token_transfer.amount)
  end

  defp prepare_token_transfer(%{token_type: "ERC-404"} = token_transfer, max_block_number, decoded_input) do
    token_transfer
    |> prepare_common_token_transfer(max_block_number, decoded_input)
    |> Map.put_new(:tokenID, to_string(List.first(token_transfer.token_ids)))
    |> Map.put_new(:value, to_string(List.first(token_transfer.amounts)))
  end

  defp prepare_token_transfer(%{token_type: "ERC-20"} = token_transfer, max_block_number, decoded_input) do
    token_transfer
    |> prepare_common_token_transfer(max_block_number, decoded_input)
    |> Map.put_new(:value, to_string(token_transfer.amount))
  end

  defp prepare_token_transfer(%{token_type: "ZRC-2"} = token_transfer, max_block_number, decoded_input) do
    token_transfer
    |> prepare_common_token_transfer(max_block_number, decoded_input)
    |> Map.put_new(:value, to_string(token_transfer.amount))
  end

  defp prepare_token_transfer(%{token_type: "ERC-7984"} = token_transfer, max_block_number, decoded_input) do
    token_transfer
    |> prepare_common_token_transfer(max_block_number, decoded_input)
    |> Map.put_new(:value, nil)
  end

  defp prepare_token_transfer(token_transfer, max_block_number, decoded_input) do
    prepare_common_token_transfer(token_transfer, max_block_number, decoded_input)
  end

  defp prepare_decoded_input({:ok, method_id, text, _mapping}) do
    %{
      "methodId" => method_id,
      "functionName" => text
    }
  end

  defp prepare_decoded_input(_) do
    %{
      "methodId" => "",
      "functionName" => ""
    }
  end

  defp prepare_block(block) do
    %{
      "blockNumber" => to_string(block.number),
      "timeStamp" => to_string(block.timestamp)
    }
  end

  defp prepare_token(token) do
    %{
      "balance" => to_string(token.balance),
      "contractAddress" => to_string(token.contract_address_hash),
      "name" => token.name,
      "decimals" => to_string(token.decimals),
      "symbol" => token.symbol,
      "type" => token.type
    }
    |> (&if(is_nil(token.id), do: &1, else: Map.put(&1, "id", token.id))).()
  end

  defp balance(address) do
    address.fetched_coin_balance && address.fetched_coin_balance.value && "#{address.fetched_coin_balance.value}"
  end
end
