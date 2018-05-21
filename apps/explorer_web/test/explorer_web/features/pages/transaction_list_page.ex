defmodule ExplorerWeb.TransactionListPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1]

  alias Explorer.Chain.Transaction

  def click_transaction(session, %Transaction{hash: transaction_hash}) do
    click(session, css("[data-test='transaction_hash'][data-transaction-hash='#{transaction_hash}']"))
  end

  def visit_page(session) do
    visit(session, "/en/transactions")
  end
end
