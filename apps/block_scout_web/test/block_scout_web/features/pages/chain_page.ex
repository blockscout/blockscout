# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.ChainPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  alias Explorer.Chain.{Address, Block, Transaction}

  def block(%Block{number: block_number}) do
    by_css("[data-block-number='#{block_number}']")
  end

  def blocks(count: count) do
    count(filter(by_css("[data-selector='chain-block']"), visible: true), count)
  end

  def contract_creation(%Transaction{created_contract_address_hash: hash}) do
    checksum = Address.checksum(hash)
    by_css(by_test_id("contract-creation"), "[data-address-hash='#{checksum}']")
  end

  def place_holder_blocks(count) do
    count(filter(by_css("[data-selector='place-holder']"), visible: true), count)
  end

  def search(session, text) do
    session
    |> fill(filter(by_test_id("search_input"), visible: true), text)
    |> press(filter(by_test_id("search_input"), visible: true), "Enter")
  end

  def token_transfers(%Transaction{hash: transaction_hash}, count: count) do
    count(
      filter(by_test_id(by_css("[data-identifier-hash='#{transaction_hash}']"), "token_transfer"), visible: true),
      count
    )
  end

  def token_transfers_expansion(%Transaction{hash: transaction_hash}) do
    by_test_id(by_css("[data-identifier-hash='#{transaction_hash}']"), "token_transfers_expansion")
  end

  def transactions(count: count) do
    count(filter(by_test_id("chain_transaction"), visible: true), count)
  end

  def visit_page(session) do
    visit(session, "/")
  end
end
