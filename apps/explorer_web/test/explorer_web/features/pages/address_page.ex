defmodule ExplorerWeb.AddressPage do
  @moduledoc false

  use Wallaby.DSL
  import Wallaby.Query, only: [css: 1, css: 2]
  alias Explorer.Chain.{Address, InternalTransaction, Hash, Transaction}

  def apply_filter(session, direction) do
    session
    |> click(css("[data-test='filter_dropdown']", text: "Filter: All"))
    |> click(css("[data-test='filter_option']", text: direction))
  end

  def balance do
    css("[data-test='address_balance']")
  end

  def click_internal_transactions(session) do
    click(session, css("[data-test='internal_transactions_tab_link']"))
  end

  def contract_creation(%InternalTransaction{created_contract_address_hash: hash}) do
    css("[data-address-hash='#{hash}']", text: to_string(hash))
  end

  def detail_hash(%Address{hash: address_hash}) do
    css("[data-test='address_detail_hash']", text: to_string(address_hash))
  end

  def internal_transactions(count: count) do
    css("[data-test='internal_transaction']", count: count)
  end

  def transaction(%Transaction{hash: transaction_hash}), do: transaction(transaction_hash)

  def transaction(%Hash{} = hash) do
    hash
    |> to_string()
    |> transaction()
  end

  def transaction(transaction_hash) do
    css("[data-transaction-hash='#{transaction_hash}']")
  end

  def transaction_count do
    css("[data-test='transaction_count']")
  end

  def visit_page(session, %Address{hash: address_hash}), do: visit_page(session, address_hash)

  def visit_page(session, address_hash) do
    visit(session, "/en/addresses/#{address_hash}")
  end
end
