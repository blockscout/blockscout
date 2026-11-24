# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.TransactionListPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  alias Explorer.Chain.Transaction

  def click_transaction(session, %Transaction{hash: transaction_hash}) do
    click(session, by_test_id(by_css("[data-identifier-hash='#{transaction_hash}']"), "transaction_hash_link"))
  end

  def contract_creation(%Transaction{hash: hash}) do
    filter(by_test_id(by_css("[data-identifier-hash='#{hash}']"), "transaction_type"), has_text: "Contract Creation")
  end

  def transaction(%Transaction{hash: transaction_hash}) do
    by_css("[data-identifier-hash='#{transaction_hash}']")
  end

  def transaction_status(%Transaction{hash: transaction_hash}) do
    by_test_id(by_css("[data-identifier-hash='#{transaction_hash}']"), "transaction_status")
  end

  def visit_page(session) do
    visit(session, "/txs")
  end

  def visit_pending_transactions_page(session) do
    visit(session, "/pending-transactions")
  end
end
