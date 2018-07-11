defmodule ExplorerWeb.TransactionListPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.{Transaction, Transaction}

  def click_transaction(session, %Transaction{hash: transaction_hash}) do
    click(session, css("[data-transaction-hash='#{transaction_hash}'] [data-test='transaction_hash_link']"))
  end

  def click_pending(session) do
    click(session, css("[data-test='pending_transactions_link']"))
  end

  def contract_creation(%Transaction{hash: hash}) do
    css("[data-transaction-hash='#{hash}']", text: "Contract Creation")
  end

  def transaction(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}']")
  end

  def visit_page(session) do
    visit(session, "/en/transactions")
  end
end
