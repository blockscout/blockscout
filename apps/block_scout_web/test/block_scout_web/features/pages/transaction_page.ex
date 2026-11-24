# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.TransactionPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  alias Explorer.Chain.{Transaction, Hash}

  def click_logs(session) do
    click(session, by_test_id("transaction_logs_link"))
  end

  def detail_hash(%Transaction{hash: transaction_hash}) do
    filter(by_test_id("transaction_detail_hash"), has_text: Hash.to_string(transaction_hash))
  end

  def is_pending() do
    filter(by_css("[data-selector='block-number']"), has_text: "Pending")
  end

  def visit_page(session, %Transaction{hash: transaction_hash}) do
    visit(session, "/tx/#{transaction_hash}")
  end
end
