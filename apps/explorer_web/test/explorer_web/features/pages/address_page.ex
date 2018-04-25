defmodule ExplorerWeb.AddressPage do
  @moduledoc false

  use Wallaby.DSL
  import Wallaby.Query, only: [css: 1, css: 2]
  alias Explorer.Chain.{Address, Transaction}

  def visit_page(session, %Address{hash: address_hash}), do: visit_page(session, address_hash)

  def visit_page(session, address_hash) do
    visit(session, "/en/addresses/#{address_hash}")
  end

  @internal_transactions_link_selector "[data-test='internal_transactions_tab_link']"
  def click_internal_transactions(session) do
    click(session, css(@internal_transactions_link_selector))
  end

  @transaction_selector "[data-test='transaction_hash']"
  def transaction(%Transaction{hash: transaction_hash}), do: transaction(transaction_hash)

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
    |> click(css("[data-test='filter_option']", text: direction))
  end

  def balance do
    css("[data-test='address_balance']")
  end
end
