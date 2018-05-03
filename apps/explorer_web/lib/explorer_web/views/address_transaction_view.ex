defmodule ExplorerWeb.AddressTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  defdelegate fee(transaction), to: TransactionView

  def format_current_filter(filter) do
    case filter do
      "to" -> gettext("To")
      "from" -> gettext("From")
      _ -> gettext("All")
    end
  end

  defdelegate status(transacton), to: TransactionView
  defdelegate value(transaction), to: TransactionView
end
