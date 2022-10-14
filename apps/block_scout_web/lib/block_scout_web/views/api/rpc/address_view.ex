defmodule BlockScoutWeb.API.RPC.AddressView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Address}
  alias Explorer.Chain
  alias BlockScoutWeb.API.EthRPC.View, as: EthRPCView
  alias BlockScoutWeb.API.RPC.RPCView

  def render("listaccounts.json", %{accounts: accounts}) do
    accounts = Enum.map(accounts, &prepare_account/1)
    RPCView.render("show.json", data: accounts)
  end

  def render("balance.json", %{addresses: [address]}) do
    RPCView.render("show.json",
      data: %{balance: balance(address), lastBalanceUpdate: address.fetched_coin_balance_block_number}
    )
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

  def render("tokentx.json", %{token_transfers: token_transfers}) do
    data = Enum.map(token_transfers, &prepare_token_transfer/1)
    RPCView.render("show.json", data: data)
  end

  def render("tokenbalance.json", %{token_balance: token_balance}) do
    RPCView.render("show.json", data: to_string(token_balance))
  end

  def render("token_list.json", %{
    token_list: tokens, has_next_page: has_next_page, next_page_path: next_page_path}) do
    data = %{
      "result" => Enum.map(tokens, &prepare_token/1),
      "hasNextPage" => has_next_page,
      "nextPagePath" => next_page_path
    }
    RPCView.render("show_data.json", data: data)
  end

  def render("getlisttokentransfers.json", %{
    token_transfers: token_transfers, has_next_page: has_next_page, next_page_path: next_page_path}) do
    data = %{
      "result" => Enum.map(token_transfers, &prepare_common_token_transfer_for_api/1),
      "hasNextPage" => has_next_page,
      "nextPagePath" => next_page_path
    }
    RPCView.render("show_data.json", data: data)
  end

  def render("getminedblocks.json", %{blocks: blocks}) do
    data = Enum.map(blocks, &prepare_block/1)
    RPCView.render("show.json", data: data)
  end

  def render("gettopaddressesbalance.json", %{
      top_addresses_balance: items, has_next_page: has_next_page, next_page_path: next_page_path})
    do
    data = %{
      "result" => Enum.map(items, &prepare_top_addresses_balance/1),
      "hasNextPage" => has_next_page,
      "nextPagePath" => next_page_path
    }
    RPCView.render("show_data.json", data: data)
  end

  def render("getcoinbalancehistory.json", %{
      coin_balances: coin_balances, has_next_page: has_next_page, next_page_path: next_page_path})
    do
    data = %{
      "result" => Enum.map(coin_balances, &prepare_coin_balance_history/1),
      "hasNextPage" => has_next_page,
      "nextPagePath" => next_page_path
    }
    RPCView.render("show_data.json", data: data)
  end

  def render("getaddresscounters.json", %{
      transaction_count: transactions_from_db,
      token_transfer_count: token_transfers_from_db,
      gas_usage_count: address_gas_usage_from_db,
      validation_count: validation_count})
    do
    data = %{
      "transactionCount" => transactions_from_db,
      "tokenTransferCount" => token_transfers_from_db,
      "gasUsageCount" => address_gas_usage_from_db,
      "validationCount" => validation_count
    }
    RPCView.render("show.json", data: data)
  end

  def render("eth_get_balance.json", %{balance: balance}) do
    EthRPCView.render("show.json", %{result: balance, id: 0})
  end

  def render("eth_get_balance_error.json", %{error: message}) do
    EthRPCView.render("error.json", %{error: message, id: 0})
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

  defp prepare_top_addresses_balance(item) do
    address = item[:address]
    txn_count = item[:tx_count]
    %{
      "balance" => to_string(address.fetched_coin_balance && address.fetched_coin_balance.value),
      "address" => to_string(address.hash),
      "txnCount" => txn_count
    }
  end

  defp prepare_coin_balance_history(coin_balance) do
    %{
      "addressHash" => coin_balance.address_hash,
      "blockNumber" => coin_balance.block_number,
      "blockTimestamp" => coin_balance.block_timestamp,
      "delta" => coin_balance.delta,
      "insertedAt" => coin_balance.inserted_at,
      "transactionHash" => coin_balance.transaction_hash,
      "transactionValue" => to_string(coin_balance.transaction_value && coin_balance.transaction_value.value),
      "updatedAt" => coin_balance.updated_at,
      "value" => to_string(coin_balance.value && coin_balance.value.value),
      "valueFetchedAt" => coin_balance.value_fetched_at
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
      "timeStamp" => "#{DateTime.to_unix(internal_transaction.transaction.block.timestamp)}",
      "from" => "#{internal_transaction.from_address_hash}",
      "fromAddressName" => prepare_address_name(internal_transaction.from_address.names),
      "to" => "#{internal_transaction.to_address_hash}",
      "toAddressName" => prepare_address_name(internal_transaction.to_address.names),
      "value" => "#{internal_transaction.value.value}",
      "contractAddress" => "#{internal_transaction.created_contract_address_hash}",
      "transactionHash" => to_string(internal_transaction.transaction_hash),
      "index" => to_string(internal_transaction.index),
      "input" => "#{internal_transaction.input}",
      "type" => "#{internal_transaction.type}",
      "callType" => "#{internal_transaction.call_type}",
      "gas" => "#{internal_transaction.gas}",
      "gasUsed" => "#{internal_transaction.gas_used}",
      "isError" => if(internal_transaction.error, do: "1", else: "0"),
      "errCode" => "#{internal_transaction.error}"
    }
  end

  defp prepare_common_token_transfer_for_api(tx) do
    %{
      "blockNumber" => tx.block_number,
      "timeStamp" => to_string(DateTime.to_unix(tx.block.timestamp)),
      "hash" => to_string(tx.hash),
      "nonce" => tx.nonce,
      "blockHash" => to_string(tx.block.hash),
      "from" => to_string(tx.from_address_hash),
      "to" => to_string(tx.to_address_hash),
      "tokenTransfers" => Enum.map(tx.token_transfers,
        fn token_transfer -> prepare_token_transfer_for_api(token_transfer) end),
      "transactionIndex" => tx.index,
      "gas" => tx.gas,
      "gasPrice" => tx.gas_price.value,
      "gasUsed" => tx.gas_used,
      "cumulativeGasUsed" => tx.cumulative_gas_used,
      "input" => tx.input,
      "contractMethodName" => get_contract_method_name(tx.input)
    }
  end

  defp prepare_common_token_transfer(token_transfer) do
    %{
      "blockNumber" => to_string(token_transfer.block_number),
      "timeStamp" => to_string(DateTime.to_unix(token_transfer.block_timestamp)),
      "hash" => to_string(token_transfer.transaction_hash),
      "nonce" => to_string(token_transfer.transaction_nonce),
      "blockHash" => to_string(token_transfer.block_hash),
      "from" => to_string(token_transfer.from_address_hash),
      "contractAddress" => to_string(token_transfer.token_contract_address_hash),
      "to" => to_string(token_transfer.to_address_hash),
      "logIndex" => to_string(token_transfer.token_log_index),
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

  defp prepare_token_transfer(%{token_type: "ERC-721"} = token_transfer) do
    token_transfer
    |> prepare_common_token_transfer()
    |> Map.put_new(:tokenID, token_transfer.token_id)
  end

  defp prepare_token_transfer(%{token_type: "ERC-1155"} = token_transfer) do
    token_transfer
    |> prepare_common_token_transfer()
    |> Map.put_new(:tokenID, token_transfer.token_id)
  end

  defp prepare_token_transfer(%{token_type: "ERC-20"} = token_transfer) do
    token_transfer
    |> prepare_common_token_transfer()
    |> Map.put_new(:value, to_string(token_transfer.amount))
  end

  defp prepare_token_transfer(token_transfer) do
    prepare_common_token_transfer(token_transfer)
  end

  defp prepare_token_transfer_for_api(token_transfer) do
    %{
      "amount" => "#{token_transfer.amount}",
      "logIndex" => "#{token_transfer.log_index}",
      "fromAddress" => "#{token_transfer.from_address}",
      "fromAddressName" => prepare_address_name(token_transfer.from_address.names),
      "toAddress" => "#{token_transfer.to_address}",
      "toAddressName" => prepare_address_name(token_transfer.to_address.names),
      "tokenContractAddress" => "#{token_transfer.token_contract_address}",
      "tokenName" => "#{token_transfer.token.name}",
      "tokenSymbol" => "#{token_transfer.token.symbol}",
      "decimals" => "#{token_transfer.token.decimals}"
    }
  end

  defp prepare_block(block) do
    %{
      "blockNumber" => to_string(block.number),
      "timeStamp" => to_string(block.timestamp)
    }
  end

  defp prepare_token(token_balances) do
    {%Address.CurrentTokenBalance{
      token_id: token_id,
      value: value,
      token: token
    }, _} = token_balances
    %{
      "balance" => value,
      "contractAddress" => to_string(token.contract_address_hash),
      "name" => token.name,
      "decimals" => token.decimals,
      "symbol" => token.symbol,
      "type" => token.type
    }
    |> (&if(is_nil(token_id), do: &1, else: Map.put(&1, "id", token_id))).()
  end

  defp balance(address) do
    address.fetched_coin_balance && address.fetched_coin_balance.value && "#{address.fetched_coin_balance.value}"
  end

  defp prepare_address_name(address_names) do
    case address_names do
      [_|_] ->
        Enum.at(address_names, 0).name
      _ ->
        ""
    end
  end

  defp get_contract_method_name(input) do
    case Chain.get_contract_method_by_input_data(input) do
      nil ->
        nil
      contract_method ->
        contract_method.abi["name"]
    end
  end
end
