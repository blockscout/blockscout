defmodule BlockScoutWeb.TransactionPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.{Transaction, Hash}

  def block_confirmations() do
    css("[data-selector='block-confirmations']")
  end

  def click_logs(session) do
    click(session, css("[data-test='transaction_logs_link']"))
  end

  def detail_hash(%Transaction{hash: transaction_hash}) do
    css("[data-test='transaction_detail_hash']", text: Hash.to_string(transaction_hash))
  end

  def visit_page(session, %Transaction{hash: transaction_hash}) do
    visit(session, "/en/transactions/#{transaction_hash}")
  end

  def visit_page(session, transaction_hash = %Hash{}) do
    visit(session, "/en/transactions/#{transaction_hash}")
  end
end
