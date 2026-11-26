# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.TransactionLogsPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  import BlockScoutWeb.Routers.WebRouter.Helpers, only: [transaction_log_path: 3]

  alias Explorer.Chain.Transaction
  alias BlockScoutWeb.Endpoint

  def logs(count: count) do
    count(filter(by_test_id("transaction_log"), visible: true), count)
  end

  def visit_page(session, %Transaction{} = transaction) do
    visit(session, transaction_log_path(Endpoint, :index, transaction))
  end

  def click_address(session, address) do
    click(session, and_(by_test_id("log_address_link"), by_css("[data-address-hash='#{address}']")))
  end
end
