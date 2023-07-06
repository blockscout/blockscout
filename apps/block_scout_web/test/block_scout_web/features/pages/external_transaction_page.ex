defmodule BlockScoutWeb.ExternalTransactionPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.{ExternalTransaction, Hash}

  def click_logs(session) do
    click(session, css("[data-test='transaction_logs_link']"))
  end

  def detail_hash(%ExternalTransaction{hash: transaction_hash}) do
    css("[data-test='transaction_detail_hash']", text: Hash.to_string(transaction_hash))
  end

  def is_pending() do
    css("[data-selector='block-number']", text: "Pending")
  end

  def visit_page(session, %ExternalTransaction{hash: transaction_hash}) do
    IO.puts(transaction_hash)
    visit(session, "/etx/#{transaction_hash}")
  end
end
