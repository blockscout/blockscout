defmodule EthereumJSONRPC.Celo.TransactionParsing do
  @moduledoc "Functions to parse and normalise keys of typed transactions"

  @optional_parameters %{
    "created" => :created_contract_address_hash,
    # type is optional for legacy transactions
    "type" => :type,
    # this is currently included for all celo transaction types but may be removed in future
    "gasPrice" => :gas_price,
    "accessList" => :access_list
  }

  def parse_legacy_transaction(transaction) do
    transaction
    |> base_transaction()
  end

  def parse_access_list_transaction(transaction) do
    transaction
    |> base_transaction()
  end

  def parse_dynamic_fee_transaction(
        %{
          "maxFeePerGas" => max_fee_per_gas,
          "maxPriorityFeePerGas" => max_priority_fee_per_gas
        } = transaction
      ) do
    transaction
    |> base_transaction()
    |> Map.merge(%{max_fee_per_gas: max_fee_per_gas, max_priority_fee_per_gas: max_priority_fee_per_gas})
  end

  # supposed to always be on the response object, but isn't...
  @celo_optional_parameters %{"maxFeePerGas" => :max_fee_per_gas, "maxPriorityFeePerGas" => :max_priority_fee_per_gas}
  def parse_celo_transaction(transaction) do
    celo_transaction = transaction |> base_transaction()

    @celo_optional_parameters
    |> Enum.reduce(celo_transaction, fn {k, v}, acc ->
      optional_parameter(transaction, acc, k, v)
    end)
  end

  def base_transaction(
        %{
          "blockHash" => block_hash,
          "blockNumber" => block_number,
          "from" => from_address_hash,
          "feeCurrency" => gas_currency_hash,
          "gas" => gas,
          "gatewayFee" => gateway_fee,
          "gatewayFeeRecipient" => gas_fee_recipient_hash,
          "hash" => hash,
          "input" => input,
          "nonce" => nonce,
          "r" => r,
          "s" => s,
          "to" => to_address_hash,
          "transactionIndex" => index,
          "v" => v,
          "value" => value
        } = transaction
      ) do
    result = %{
      block_hash: block_hash,
      block_number: block_number,
      from_address_hash: from_address_hash,
      gas: gas,
      gas_currency_hash: gas_currency_hash,
      gas_fee_recipient_hash: gas_fee_recipient_hash,
      gateway_fee: gateway_fee,
      hash: hash,
      index: index,
      input: input,
      nonce: nonce,
      r: r,
      s: s,
      to_address_hash: to_address_hash,
      v: v,
      value: value,
      transaction_index: index
    }

    @optional_parameters
    |> Enum.reduce(result, fn {k, v}, acc ->
      optional_parameter(transaction, acc, k, v)
    end)
  end

  # explicitly ignoring access list parameter
  defp optional_parameter(_source, %{} = destination, "accessList", _destination_key), do: destination

  defp optional_parameter(%{} = source, %{} = destination, source_key, destination_key) do
    if Map.has_key?(source, source_key) do
      value = source |> Map.get(source_key)

      destination |> Map.put(destination_key, value)
    else
      destination
    end
  end
end
