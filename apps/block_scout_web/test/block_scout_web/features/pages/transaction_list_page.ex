defmodule BlockScoutWeb.TransactionListPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.Transaction

  def click_transaction(session, %Transaction{hash: transaction_hash}) do
    click(session, css("[data-transaction-hash='#{transaction_hash}'] [data-test='transaction_hash_link']"))
  end

  def click_pending(session) do
    click(session, css("[data-test='pending_transactions_link']"))
  end

  def contract_creation(%Transaction{hash: hash}) do
    css("[data-transaction-hash='#{hash}'] [data-test='transaction_type']", text: "Contract Creation")
  end

  def transaction(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}']")
  end

  def transaction_block_number(%Transaction{hash: transaction_hash}, block_number) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='block_number']", text: "Block ##{block_number}")
  end

  def transaction_status(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='transaction_status']")
  end

  def visit_page(session) do
    visit(session, "/txs")
  end
end
