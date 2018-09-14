defmodule BlockScoutWeb.API.RPC.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.RPC.RPCView

  def render("gettxreceiptstatus.json", %{status: status}) do
    prepared_status = prepare_tx_receipt_status(status)
    RPCView.render("show.json", data: %{"status" => prepared_status})
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_tx_receipt_status(""), do: ""

  defp prepare_tx_receipt_status(nil), do: ""

  defp prepare_tx_receipt_status(:ok), do: "1"

  defp prepare_tx_receipt_status(_), do: "0"
end
