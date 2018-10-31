defmodule BlockScoutWeb.API.RPC.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("gettxinfo.json", %{transaction: transaction, max_block_number: max_block_number, logs: logs}) do
    data = prepare_transaction(transaction, max_block_number, logs)
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

  defp prepare_transaction(transaction, max_block_number, logs) do
    %{
      "hash" => "#{transaction.hash}",
      "timeStamp" => "#{DateTime.to_unix(transaction.block.timestamp)}",
      "blockNumber" => "#{transaction.block_number}",
      "confirmations" => "#{max_block_number - transaction.block_number}",
      "success" => if(transaction.status == :ok, do: true, else: false),
      "from" => "#{transaction.from_address_hash}",
      "to" => "#{transaction.to_address_hash}",
      "value" => "#{transaction.value.value}",
      "input" => "#{transaction.input}",
      "gasLimit" => "#{transaction.gas}",
      "gasUsed" => "#{transaction.gas_used}",
      "logs" => Enum.map(logs, &prepare_log/1)
    }
  end

  defp prepare_log(log) do
    %{
      "address" => "#{log.address_hash}",
      "topics" => get_topics(log),
      "data" => "#{log.data}"
    }
  end

  defp get_topics(log) do
    log
    |> Map.take([:first_topic, :second_topic, :third_topic, :fourth_topic])
    |> Map.values()
  end
end
