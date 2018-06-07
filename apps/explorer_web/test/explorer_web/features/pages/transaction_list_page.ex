defmodule ExplorerWeb.TransactionListPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.{InternalTransaction, Transaction}

  def click_transaction(session, %Transaction{hash: transaction_hash}) do
    click(session, css("[data-test='transaction_hash'][data-transaction-hash='#{transaction_hash}']"))
  end

  def click_pending(session) do
    click(session, css("[data-test='pending_transactions_link']"))
  end

  def contract_creation(%InternalTransaction{created_contract_address_hash: hash}) do
    css("[data-address-hash='#{hash}']", text: "Contract Created")
  end

  def transaction(%Transaction{hash: transaction_hash}) do
    css("[data-test='transaction_hash'][data-transaction-hash='#{transaction_hash}']")
  end

  def visit_page(session) do
    visit(session, "/en/transactions")
  end
end
