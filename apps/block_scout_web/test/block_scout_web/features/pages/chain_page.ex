defmodule BlockScoutWeb.ChainPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.{Block, Transaction}

  def block(%Block{number: block_number}) do
    css("[data-block-number='#{block_number}']")
  end

  def blocks(count: count) do
    css("[data-selector='chain-block']", count: count)
  end

  def contract_creation(%Transaction{created_contract_address_hash: hash}) do
    css("[data-test='contract-creation'] [data-address-hash='#{hash}']")
  end

  def place_holder_blocks(count) do
    css("[data-selector='place-holder']", count: count)
  end

  def search(session, text) do
    session
    |> fill_in(css("[data-test='search_input']"), with: text)
    |> send_keys([:enter])
  end

  def token_transfers(%Transaction{hash: transaction_hash}, count: count) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='token_transfer']", count: count)
  end

  def token_transfers_expansion(%Transaction{hash: transaction_hash}) do
    css("[data-transaction-hash='#{transaction_hash}'] [data-test='token_transfers_expansion']")
  end

  def transactions(count: count) do
    css("[data-test='chain_transaction']", count: count)
  end

  def visit_page(session) do
    visit(session, "/")
  end
end
