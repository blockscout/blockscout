defmodule ExplorerWeb.AddressPage do
  @moduledoc false

  use Wallaby.DSL
  import Wallaby.Query, only: [css: 1, css: 2]

  def visit_page(session, address_hash) do
    visit(session, "/en/addresses/#{address_hash}")
  end

  @internal_transactions_link_selector "[data-test='internal_transactions_tab_link']"
  def click_internal_transactions(session) do
    click(session, css(@internal_transactions_link_selector))
  end

  @transaction_selector ".transactions__link--long-hash"
  def transaction(transaction_hash) do
    css(@transaction_selector, text: transaction_hash)
  end

  @internal_transactions_selector "[data-test='internal_transaction']"
  def internal_transactions(count: count) do
    css(@internal_transactions_selector, count: count)
  end

  def apply_filter(session, direction) do
    session
    |> click(css("[data-test='filter_dropdown']", text: "Filter: All"))
    |> click(css(".address__link", text: direction))
  end
end
