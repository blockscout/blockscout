defmodule BlockScoutWeb.API.V2.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.ApiView
  alias BlockScoutWeb.ABIEncodedValueView
  alias Explorer.Chain
  alias Explorer.Chain.{Transaction, Wei}

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("transaction.json", %{transaction: transaction}) do
    prepare_transaction(transaction)
  end

  def render("decoded_input.json", %{method_id: method_id, text: text, mapping: mapping, error?: _error}) do
    %{"method_id" => method_id, "method_call" => text, "mapping" => prepare_method_mapping(mapping)}
  end

  def render("revert_reason.json", %{raw: raw, decoded: decoded}) do
    %{"raw" => raw, "decoded" => decoded}
  end

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
  end

  defp prepare_transaction(transaction) do
    base_fee_per_gas = transaction.block && transaction.block.base_fee_per_gas
    max_priority_fee_per_gas = transaction.max_priority_fee_per_gas
    max_fee_per_gas = transaction.max_fee_per_gas

    priority_fee_per_gas =
      if is_nil(max_priority_fee_per_gas) or is_nil(base_fee_per_gas),
        do: nil,
        else:
          Enum.min_by([max_priority_fee_per_gas, Wei.sub(max_fee_per_gas, base_fee_per_gas)], fn x ->
            Wei.to(x, :wei)
          end)

    burned_fee =
      if !is_nil(max_fee_per_gas) and !is_nil(transaction.gas_used) and !is_nil(base_fee_per_gas) do
        if Decimal.compare(max_fee_per_gas.value, 0) == :eq do
          %Wei{value: Decimal.new(0)}
        else
          Wei.mult(base_fee_per_gas, transaction.gas_used)
        end
      else
        nil
      end

    status = transaction |> Chain.transaction_to_status() |> format_status()

    revert_reason =
      if is_binary(status) && status |> String.downcase() |> String.contains?("reverted") do
        case BlockScoutWeb.TransactionView.transaction_revert_reason(transaction) do
          {:error, _contract_not_verified, candidates} when candidates != [] ->
            {:ok, method_id, text, mapping} = Enum.at(candidates, 0)
            render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: true)

          {:ok, method_id, text, mapping} ->
            render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: true)

          _ ->
            hex = BlockScoutWeb.TransactionView.get_pure_transaction_revert_reason(transaction)
            utf8 = BlockScoutWeb.TransactionView.decoded_revert_reason(transaction)
            render(__MODULE__, "revert_reason.json", raw: hex, decoded: utf8)
        end
      end

    decoded_input_data =
      case transaction |> Transaction.decoded_input_data() |> format_decoded_input() |> debug("decoded") do
        {:ok, method_id, text, mapping} ->
          render(__MODULE__, "decoded_input.json", method_id: method_id, text: text, mapping: mapping, error?: false)

        _ ->
          nil
      end

    %{
      "hash" => transaction.hash,
      "result" => status,
      "status" => transaction.status || 0,
      "block" => transaction.block_number,
      "timestamp" => transaction.block && transaction.block.timestamp,
      "from" => transaction.from_address_hash,
      "to" => transaction.to_address_hash,
      "value" => transaction.value,
      "fee" => Tuple.to_list(Chain.fee(transaction, :wei)),
      "gas_price" => transaction.gas_price,
      "type" => transaction.type,
      "gas_used" => transaction.gas_used,
      "gas_limit" => transaction.gas,
      "max_fee_per_gas" => transaction.max_fee_per_gas,
      "max_priority_fee_per_gas" => transaction.max_priority_fee_per_gas,
      "priority_fee" => priority_fee_per_gas && Wei.mult(priority_fee_per_gas, transaction.gas_used),
      "tx_burnt_fee" => burned_fee,
      "nonce" => transaction.nonce,
      "position" => transaction.index,
      "revert_reason" => revert_reason,
      "raw_input" => transaction.input,
      "decoded_input" => decoded_input_data
      # "decoded_input": {
      #   "method_name": "submit_signature",
      #   "method_id": "0x630cea8e",
      #   "parameters": [
      #     {
      #       "name": "signature",
      #       "type": "bytes",
      #       "value": "0x0"
      #     },
      #     {
      #       "name": "message",
      #       "type": "bytes",
      #       "value": "0x01"
      #     }
      #   ]
      # },
      # "token_transfers": [
      #   {
      #     "tx_hash": "0x655a2304c3f69b0ce52a6dd25bf4377ffddcdde6397aa53d47b13c49af0ac5c8",
      #     "from": "0xd676432A77cfe7bbF5a048E375557cC18e295aE7",
      #     "to": "0x70f2534984c651d4FEd7cC48E4741ebE9dFF9b9A",
      #     "value": 0,
      #     "token_address": "0x70f2534984c651d4FEd7cC48E4741ebE9dFF9b9A",
      #     "token_symbol": "WETH"
      #   }
      # ]
    }
  end

  def prepare_method_mapping(mapping) do
    Enum.map(mapping, fn {name, type, value} ->
      %{"name" => name, "type" => type, "value" => ABIEncodedValueView.value_json(type, value)}
    end)
  end

  defp format_status({:error, reason}), do: reason
  defp format_status(status), do: status

  defp format_decoded_input({:error, _, []}), do: nil
  defp format_decoded_input({:error, :contract_not_verified, candidates}), do: Enum.at(candidates, 0)
  defp format_decoded_input({:ok, _identifier, _text, _mapping} = decoded), do: decoded
  defp format_decoded_input(_), do: nil
end
