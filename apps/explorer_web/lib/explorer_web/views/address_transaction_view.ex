defmodule ExplorerWeb.AddressTransactionView do
  use ExplorerWeb, :view

  alias ExplorerWeb.TransactionView

  defdelegate block(transaction), to: TransactionView
  defdelegate from_address(transaction), to: TransactionView
  defdelegate hash(transaction), to: TransactionView

  def format_current_filter(filter) do
    case filter do
      "to" -> gettext("To")
      "from" -> gettext("From")
      _ -> gettext("All")
    end
  end

  defdelegate status(transaction), to: TransactionView
  defdelegate to_address(transaction), to: TransactionView
end
