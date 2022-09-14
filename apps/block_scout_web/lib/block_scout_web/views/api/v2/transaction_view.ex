defmodule BlockScoutWeb.API.V2.TransactionView do
  alias BlockScoutWeb.API.V2.ApiView

  def render("message.json", assigns) do
    ApiView.render("message.json", assigns)
  end

  def render("transaction.json", %{transaction: transaction}) do
    prepare_transaction(transaction)
  end

  defp prepare_transaction(transaction) do
    %{}
  end
end
