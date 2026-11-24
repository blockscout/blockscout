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
    count(filter(by_css("[data-test='transaction_log']"), visible: true), count)
  end

  def visit_page(session, %Transaction{} = transaction) do
    visit(session, transaction_log_path(Endpoint, :index, transaction))
  end

  def click_address(session, address) do
    click(session, by_css("[data-test='log_address_link'][data-address-hash='#{address}']"))
  end
end
