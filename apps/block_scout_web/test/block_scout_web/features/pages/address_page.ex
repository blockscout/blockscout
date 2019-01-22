defmodule BlockScoutWeb.AddressPage do
  @moduledoc false

  use Wallaby.DSL
  import Wallaby.Query, only: [css: 1, css: 2]
  alias Explorer.Chain.{Address, InternalTransaction, Hash, Transaction, Token}

  def apply_filter(session, direction) do
    session
    |> click(css("[data-test='filter_dropdown']", text: "Filter: All"))
    |> click(css("[data-test='filter_option']", text: direction))
  end

  def balance do
    css("[data-test='address_balance']")
  end

  def token_balance(count: count) do
    css("[data-dropdown-token-balance-test]", count: count)
  end

  def token_balance_counter(text) do
    css("[data-tokens-count]", text: "#{text} tokens")
  end

  def token_type(count: count) do
    css("[data-token-type]", count: count)
  end

  def token_type_count(type: type, text: text) do
    css("[data-number-of-tokens-by-type='#{type}']", text: text)
  end

  def address(%Address{} = address) do
    css("[data-address-hash='#{address}']", text: to_string(address))
  end

  def contract_creator do
    css("[data-test='address_contract_creator']")
  end

  def click_internal_transactions(session) do
    click(session, css("[data-test='internal_transactions_tab_link']"))
  end

  def click_tokens(session) do
    click(session, css("[data-test='tokens_tab_link']"))
  end

  def click_coin_balance_history(session) do
    click(session, css("[data-test='coin_balance_tab_link']"))
  end

  def click_balance_dropdown_toggle(session) do
    click(session, css("[data-dropdown-toggle]"))
  end

  def fill_balance_dropdown_search(session, text) do
    fill_in(session, css("[data-filter-dropdown-tokens]"), with: text)
  end

  def click_outside_of_the_dropdown(session) do
    click(session, css("[data-test='outside_of_dropdown']"))
  end

  def click_token_transfers(session, %Token{contract_address_hash: contract_address_hash}) do
    click(session, css("[data-test='token_transfers_#{contract_address_hash}']"))
  end

  def click_show_pending_transactions(session) do
    click(session, css("[data-selector='pending-transactions-open']"))
  end

  def coin_balances(count: count) do
    css("[data-test='coin_balance']", count: count)
  end

  def contract_creation(%InternalTransaction{created_contract_address_hash: hash}) do
    css("[data-address-hash='#{hash}']", text: to_string(hash))
  end

  def detail_hash(address) do
    css("[data-test='address_detail_hash']", text: to_string(address))
  end

  def internal_transaction(%InternalTransaction{transaction_hash: transaction_hash, index: index}) do
    css(
      "[data-test='internal_transaction']" <>
        "[data-internal-transaction-transaction-hash='#{transaction_hash}']" <>
        "[data-internal-transaction-index='#{index}']"
    )
  end

  def internal_transactions(count: count) do
    css("[data-test='internal_transaction']", count: count)
  end

  def internal_transaction_address_link(
        %InternalTransaction{transaction_hash: transaction_hash, index: index, from_address_hash: address_hash},
        :from
      ) do
    checksum = Address.checksum(address_hash)

    css(
      "[data-internal-transaction-transaction-hash='#{transaction_hash}'][data-internal-transaction-index='#{index}']" <>
        " [data-test='address_hash_link']" <> " [data-address-hash='#{checksum}']"
    )
  end

  def internal_transaction_address_link(
        %InternalTransaction{transaction_hash: transaction_hash, index: index, to_address_hash: address_hash},
        :to
      ) do
    css(
      "[data-internal-transaction-transaction-hash='#{transaction_hash}'][data-internal-transaction-index='#{index}']" <>
        " [data-test='address_hash_link']" <> " [data-address-hash='#{address_hash}']"
    )
  end

  def pending_transaction(%Transaction{hash: transaction_hash}), do: pending_transaction(transaction_hash)

  def pending_transaction(transaction_hash) do
    css("[data-selector='pending-transactions-list'] [data-transaction-hash='#{transaction_hash}']")
  end

  def transaction(%Transaction{hash: transaction_hash}), do: transaction(transaction_hash)

  def transaction(%Hash{} = hash) do
    hash
    |> to_string()
    |> transaction()
  end

  def transaction(transaction_hash) do
    css("[data-identifier-hash='#{transaction_hash}']")
  end

  def transaction_address_link(%Transaction{hash: hash, from_address_hash: address_hash}, :from) do
    checksum = Address.checksum(address_hash)

    css("[data-identifier-hash='#{hash}'] [data-test='address_hash_link'] [data-address-hash='#{checksum}']")
  end

  def transaction_address_link(%Transaction{hash: hash, to_address_hash: address_hash}, :to) do
    checksum = Address.checksum(address_hash)

    css("[data-identifier-hash='#{hash}'] [data-test='address_hash_link'] [data-address-hash='#{checksum}']")
  end

  def transaction_status(%Transaction{hash: transaction_hash}) do
    css("[data-identifier-hash='#{transaction_hash}'] [data-test='transaction_status']")
  end

  def token_transfer(%Transaction{hash: transaction_hash}, %Address{} = address, count: count) do
    css(
      "[data-identifier-hash='#{transaction_hash}'] [data-test='token_transfer'] [data-address-hash='#{address}']",
      count: count
    )
  end

  def token_transfers(%Transaction{hash: transaction_hash}, count: count) do
    css("[data-identifier-hash='#{transaction_hash}'] [data-test='token_transfer']", count: count)
  end

  def token_transfers_expansion(%Transaction{hash: transaction_hash}) do
    css("[data-identifier-hash='#{transaction_hash}'] [data-test='token_transfers_expansion']")
  end

  def visit_page(session, %Address{hash: address_hash}), do: visit_page(session, address_hash)

  def visit_page(session, address_hash) do
    visit(session, "/address/#{address_hash}")
  end

  def visit_page(session) do
    visit(session, "/accounts")
  end
end
