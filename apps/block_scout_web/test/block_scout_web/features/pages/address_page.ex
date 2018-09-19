defmodule BlockScoutWeb.AddressPage do
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

  def address(%Address{hash: hash}) do
    css("[data-address-hash='#{hash}']", text: to_string(hash))
  end

  def contract_creator do
    css("[data-test='address_contract_creator']")
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

  def internal_transaction(%InternalTransaction{id: id}) do
    css("[data-test='internal_transaction'][data-internal-transaction-id='#{id}']")
  end

  def internal_transactions(count: count) do
    css("[data-test='internal_transaction']", count: count)
  end

  def internal_transaction_address_link(%InternalTransaction{id: id, from_address_hash: address_hash}, :from) do
    css("[data-internal-transaction-id='#{id}'] [data-test='address_hash_link'] [data-address-hash='#{address_hash}']")
  end

  def internal_transaction_address_link(%InternalTransaction{id: id, to_address_hash: address_hash}, :to) do
    css("[data-internal-transaction-id='#{id}'] [data-test='address_hash_link'] [data-address-hash='#{address_hash}']")
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

  def transaction_address_link(%Transaction{hash: hash, from_address_hash: address_hash}, :from) do
    css("[data-transaction-hash='#{hash}'] [data-test='address_hash_link'] [data-address-hash='#{address_hash}']")
  end

  def transaction_address_link(%Transaction{hash: hash, to_address_hash: address_hash}, :to) do
    css("[data-transaction-hash='#{hash}'] [data-test='address_hash_link'] [data-address-hash='#{address_hash}']")
  end

  def transaction_count do
    css("[data-selector='transaction-count']")
  end

  def transaction_status(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='transaction_status']")
  end

  def token_transfer(%Transaction{hash: transaction_hash}, %Address{hash: address_hash}, count: count) do
    css(
      "[data-transaction-hash='#{transaction_hash}'] [data-test='token_transfer'] [data-address-hash='#{address_hash}']",
      count: count
    )
  end

  def token_transfers(%Transaction{hash: transaction_hash}, count: count) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='token_transfer']", count: count)
  end

  def token_transfers_expansion(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='token_transfers_expansion']")
  end

  def visit_page(session, %Address{hash: address_hash}), do: visit_page(session, address_hash)

  def visit_page(session, address_hash) do
    visit(session, "/address/#{address_hash}")
  end

  def visit_page(session) do
    visit(session, "/accounts")
  end
end
