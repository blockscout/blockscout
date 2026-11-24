# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.AddressPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator
  alias Explorer.Chain.{Address, InternalTransaction, Hash, Transaction, Token}

  def apply_filter(session, direction) do
    session
    |> click(filter(by_css("[data-test='filter_dropdown']"), has_text: "Filter: All"))
    |> click(filter(by_css("[data-test='filter_option']"), has_text: direction))
  end

  def balance do
    by_css("[data-test='address_balance']")
  end

  def token_balance(count: count) do
    count(filter(by_css("[data-dropdown-token-balance-test]"), visible: true), count)
  end

  def token_balance_counter(text) do
    filter(by_css("[data-tokens-count]"), has_text: "#{text} tokens")
  end

  def token_type(count: count) do
    count(filter(by_css("[data-token-type]"), visible: true), count)
  end

  def token_type_count(type: type, text: text) do
    filter(by_css("[data-number-of-tokens-by-type='#{type}']"), has_text: text)
  end

  def address(%Address{} = address) do
    filter(by_css("[data-address-hash='#{address}']"), has_text: to_string(address))
  end

  def contract_creator do
    by_css("[data-test='address_contract_creator']")
  end

  def click_internal_transactions(session) do
    click(session, by_css("[data-test='internal_transactions_tab_link']"))
  end

  def click_tokens(session) do
    click(session, by_css("[data-test='tokens_tab_link']"))
  end

  def click_coin_balance_history(session) do
    click(session, by_css("[data-test='coin_balance_tab_link']"))
  end

  def click_balance_dropdown_toggle(session) do
    click(session, by_css("[data-dropdown-toggle]"))
  end

  def fill_balance_dropdown_search(session, text) do
    fill(session, by_css("[data-filter-dropdown-tokens]"), text)
  end

  def click_outside_of_the_dropdown(session) do
    click(session, by_css("[data-test='outside_of_dropdown']"))
  end

  def click_token_transfers(session, %Token{contract_address_hash: contract_address_hash}) do
    click(session, by_css("[data-test='token_transfers_#{contract_address_hash}']"))
  end

  def click_show_pending_transactions(session) do
    click(session, by_css("[data-selector='pending-transactions-open']"))
  end

  def coin_balances(count: count) do
    count(filter(by_css("[data-test='coin_balance']"), visible: true), count)
  end

  def contract_creation(%InternalTransaction{created_contract_address_hash: hash}) do
    filter(by_css("[data-address-hash='#{hash}']"), has_text: to_string(hash))
  end

  def detail_hash(address) do
    filter(by_css("[data-test='address_detail_hash']"), has_text: to_string(address))
  end

  def internal_transaction(%InternalTransaction{index: index} = internal_transaction) do
    by_css(
      "[data-test='internal_transaction']" <>
        "[data-internal-transaction-transaction-hash='#{internal_transaction.transaction.hash}']" <>
        "[data-internal-transaction-index='#{index}']"
    )
  end

  def internal_transactions(count: count) do
    count(filter(by_css("[data-test='internal_transaction']"), visible: true), count)
  end

  def internal_transaction_address_link(
        %InternalTransaction{index: index, from_address_hash: address_hash} = internal_transaction,
        :from
      ) do
    checksum = Address.checksum(address_hash)

    by_css(
      "[data-internal-transaction-transaction-hash='#{internal_transaction.transaction.hash}'][data-internal-transaction-index='#{index}']" <>
        " [data-test='address_hash_link']" <> " [data-address-hash='#{checksum}']"
    )
  end

  def internal_transaction_address_link(
        %InternalTransaction{index: index, to_address_hash: address_hash} = internal_transaction,
        :to
      ) do
    by_css(
      "[data-internal-transaction-transaction-hash='#{internal_transaction.transaction.hash}'][data-internal-transaction-index='#{index}']" <>
        " [data-test='address_hash_link']" <> " [data-address-hash='#{address_hash}']"
    )
  end

  def pending_transaction(%Transaction{hash: transaction_hash}), do: pending_transaction(transaction_hash)

  def pending_transaction(transaction_hash) do
    by_css("[data-selector='pending-transactions-list'] [data-transaction-hash='#{transaction_hash}']")
  end

  def transaction(%Transaction{hash: transaction_hash}), do: transaction(transaction_hash)

  def transaction(%Hash{} = hash) do
    hash
    |> to_string()
    |> transaction()
  end

  def transaction(transaction_hash) do
    by_css("[data-identifier-hash='#{transaction_hash}']")
  end

  def transaction_address_link(%Transaction{hash: hash, from_address_hash: address_hash}, :from) do
    checksum = Address.checksum(address_hash)

    by_css("[data-identifier-hash='#{hash}'] [data-test='address_hash_link'] [data-address-hash='#{checksum}']")
  end

  def transaction_address_link(%Transaction{hash: hash, to_address_hash: address_hash}, :to) do
    checksum = Address.checksum(address_hash)

    by_css("[data-identifier-hash='#{hash}'] [data-test='address_hash_link'] [data-address-hash='#{checksum}']")
  end

  def transaction_status(%Transaction{hash: transaction_hash}) do
    by_css("[data-identifier-hash='#{transaction_hash}'] [data-test='transaction_status']")
  end

  def token_transfer(%Transaction{hash: transaction_hash}, %Address{} = address, count: count) do
    count(
      filter(
        by_css(
          "[data-identifier-hash='#{transaction_hash}'] [data-test='token_transfer'] [data-address-hash='#{address}']"
        ),
        visible: true
      ),
      count
    )
  end

  def token_transfers(%Transaction{hash: transaction_hash}, count: count) do
    count(
      filter(by_css("[data-identifier-hash='#{transaction_hash}'] [data-test='token_transfer']"), visible: true),
      count
    )
  end

  def token_transfers_expansion(%Transaction{hash: transaction_hash}) do
    by_css("[data-identifier-hash='#{transaction_hash}'] [data-test='token_transfers_expansion']")
  end

  def visit_page(session, %Address{hash: address_hash}), do: visit_page(session, address_hash)

  def visit_page(session, address_hash) do
    visit(session, "/address/#{address_hash}")
  end

  def visit_page(session) do
    visit(session, "/accounts")
  end
end
