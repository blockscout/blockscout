# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.RPC.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView
  alias Explorer.Chain.Transaction
  @log_topic_fields ~w(first_topic second_topic third_topic fourth_topic)a

  def render("gettxreceiptstatus.json", %{status: status}) do
    prepared_status = prepare_transaction_receipt_status(status)
    RPCView.render("show.json", data: %{"status" => prepared_status})
  end

  def render("getstatus.json", %{error: error}) do
    RPCView.render("show.json", data: prepare_error(error))
  end

  def render("gettxinfo.json", %{transaction: transaction, logs: logs} = assigns) do
    result =
      transaction
      |> transaction_info(assigns.block_height)
      |> Map.merge(%{
        "logs" => Enum.map(logs, &log_info/1),
        "next_page_params" => assigns.next_page_params
      })

    RPCView.render("show.json", data: result)
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  # Fields of the `gettxinfo` result taken from the transaction itself.
  defp transaction_info(transaction, block_height) do
    info = %{
      "hash" => to_string(transaction.hash),
      "timeStamp" => transaction |> Transaction.block_timestamp() |> DateTime.to_unix() |> to_string(),
      "blockNumber" => to_string(transaction.block_number),
      "confirmations" => confirmations(transaction.block_number, block_height),
      "success" => transaction.status == :ok,
      "from" => to_string(transaction.from_address_hash),
      "to" => to_string(transaction.to_address_hash),
      "value" => to_string(transaction.value.value),
      "input" => to_string(transaction.input),
      "gasLimit" => to_string(transaction.gas),
      "gasUsed" => to_string(transaction.gas_used),
      "gasPrice" => to_string(transaction.gas_price.value),
      "revertReason" => to_string(transaction.revert_reason)
    }

    Map.merge(info, RPCView.l1_fee_fields(transaction))
  end

  defp confirmations(nil, _block_height), do: "0"
  defp confirmations(block_number, block_height), do: to_string(block_height - block_number)

  defp log_info(log) do
    %{
      "address" => to_string(log.address_hash),
      "topics" => Enum.map(@log_topic_fields, &Map.fetch!(log, &1)),
      "data" => to_string(log.data),
      "index" => to_string(log.index)
    }
  end

  defp prepare_transaction_receipt_status(""), do: ""

  defp prepare_transaction_receipt_status(nil), do: ""

  defp prepare_transaction_receipt_status(:ok), do: "1"

  defp prepare_transaction_receipt_status(_), do: "0"

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
end
