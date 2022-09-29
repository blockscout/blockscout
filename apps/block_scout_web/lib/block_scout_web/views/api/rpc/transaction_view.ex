defmodule BlockScoutWeb.API.RPC.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("gettxinfo.json", %{
        transaction: transaction,
        block_height: block_height,
        logs: logs,
        next_page_params: next_page_params
      }) do
    data = prepare_transaction(transaction, block_height, logs, next_page_params)
    RPCView.render("show.json", data: data)
  end

  def render("gettxcosmosinfo.json", %{
    transaction: transaction,
    block_height: block_height,
    logs: logs,
    next_page_params: next_page_params
  }) do
    data = prepare_transaction(transaction, block_height, logs, next_page_params)
    RPCView.render("show.json", data: data)
  end

  def render("gettxreceiptstatus.json", %{status: status}) do
    prepared_status = prepare_tx_receipt_status(status)
    RPCView.render("show.json", data: %{"status" => prepared_status})
  end

  def render("getstatus.json", %{error: error}) do
    RPCView.render("show.json", data: prepare_error(error))
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_tx_receipt_status(""), do: ""

  defp prepare_tx_receipt_status(nil), do: ""

  defp prepare_tx_receipt_status(:ok), do: "1"

  defp prepare_tx_receipt_status(_), do: "0"

  defp prepare_error("") do
    %{
      "isError" => "0",
      "errDescription" => ""
    }
  end

  defp prepare_error(error) when is_binary(error) do
    %{
      "isError" => "1",
      "errDescription" => error
    }
  end

  defp prepare_error(error) when is_atom(error) do
    %{
      "isError" => "1",
      "errDescription" => error |> Atom.to_string() |> String.replace("_", " ")
    }
  end

  defp prepare_transaction(transaction, block_height, logs, next_page_params) do
    %{
      "hash" => "#{transaction.hash}",
      "hashCosmos" => "#{transaction.cosmos_hash}",
      "timeStamp" => "#{DateTime.to_unix(transaction.block.timestamp)}",
      "blockHeight" => "#{transaction.block_number}",
      "blockHash" => "#{transaction.block_hash}",
      "confirmations" => "#{block_height - transaction.block_number}",
      "success" => if(transaction.status == :ok, do: true, else: false),
      "from" => "#{transaction.from_address_hash}",
      "to" => "#{transaction.to_address_hash}",
      "value" => "#{transaction.value.value}",
      "input" => "#{transaction.input}",
      "gasLimit" => "#{transaction.gas}",
      "gasUsed" => "#{transaction.gas_used}",
      "gasPrice" => "#{transaction.gas_price.value}",
      "cumulativeGasUsed" => "#{transaction.cumulative_gas_used}",
      "index" => "#{transaction.index}",
      "createdContractCodeIndexedAt" => "#{transaction.created_contract_code_indexed_at}",
      "nonce" => "#{transaction.nonce}",
      "r" => "#{transaction.r}",
      "s" => "#{transaction.s}",
      "v" => "#{transaction.v}",
      "logs" => Enum.map(logs, &prepare_log/1),
      "maxPriorityFeePerGas" => "#{transaction.max_priority_fee_per_gas.value}",
      "maxFeePerGas" => "#{transaction.max_fee_per_gas.value}",
      "revertReason" => "#{transaction.revert_reason}",
      "type" => "#{transaction.type}",
      "next_page_params" => next_page_params
    }
  end

  defp prepare_log(log) do
    %{
      "address" => "#{log.address_hash}",
      "topics" => get_topics(log),
      "data" => "#{log.data}",
      "index" => "#{log.index}"
    }
  end

  defp get_topics(log) do
    [log.first_topic, log.second_topic, log.third_topic, log.fourth_topic]
  end
end
