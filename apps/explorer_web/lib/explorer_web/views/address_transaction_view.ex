defmodule ExplorerWeb.AddressTransactionView do
  use ExplorerWeb, :view

  import ExplorerWeb.AddressView, only: [contract?: 1, smart_contract_verified?: 1]

  alias ExplorerWeb.TransactionView

  def format_current_filter(filter) do
    case filter do
      "to" -> gettext("To")
      "from" -> gettext("From")
      _ -> gettext("All")
    end
  end

  defdelegate formatted_status(transaction), to: TransactionView
  defdelegate status(transaction), to: TransactionView
end
