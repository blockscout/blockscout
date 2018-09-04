defmodule BlockScoutWeb.BlockPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.{Block, InternalTransaction, Transaction}

  def contract_creation(%InternalTransaction{created_contract_address_hash: hash}) do
    css("[data-address-hash='#{hash}']")
  end

  def detail_number(%Block{number: block_number}) do
    css("[data-test='block_detail_number']", text: to_string(block_number))
  end

  def token_transfers(%Transaction{hash: transaction_hash}, count: count) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='token_transfer']", count: count)
  end

  def token_transfers_expansion(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='token_transfers_expansion']")
  end

  def transaction(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}']")
  end

  def transaction_status(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='transaction_status']")
  end

  def visit_page(session, %Block{number: block_number}) do
    visit(session, "/blocks/#{block_number}/transactions")
  end
end
