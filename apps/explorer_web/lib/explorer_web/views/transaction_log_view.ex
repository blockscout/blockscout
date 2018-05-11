defmodule ExplorerWeb.TransactionLogView do
  use ExplorerWeb, :view
  @dialyzer :no_match

  alias ExplorerWeb.TransactionView

  defdelegate format_usd(txn, token), to: TransactionView
end
