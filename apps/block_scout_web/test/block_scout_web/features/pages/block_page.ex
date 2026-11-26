# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.BlockPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  alias Explorer.Chain.{Address, Block, InternalTransaction, Transaction}

  def contract_creation(%InternalTransaction{created_contract_address_hash: hash}) do
    checksum = Address.checksum(hash)
    by_css("[data-address-hash='#{checksum}']")
  end

  def detail_number(%Block{number: block_number}) do
    filter(by_test_id("block_detail_number"), has_text: to_string(block_number))
  end

  def page_type(type) do
    filter(by_test_id("detail_type"), has_text: type)
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

  def transaction(%Transaction{hash: transaction_hash}) do
    by_css("[data-identifier-hash='#{transaction_hash}']")
  end

  def transaction_status(%Transaction{hash: transaction_hash}) do
    by_test_id(by_css("[data-identifier-hash='#{transaction_hash}']"), "transaction_status")
  end

  def uncle_link(%Block{hash: hash}) do
    and_(by_test_id("uncle_link"), by_css("[data-uncle-hash='#{hash}']"))
  end

  def visit_page(session, %Block{number: block_number, consensus: true}) do
    visit(session, "/blocks/#{block_number}")
  end

  def visit_page(session, %Block{hash: hash}) do
    visit(session, "/blocks/#{hash}")
  end
end
