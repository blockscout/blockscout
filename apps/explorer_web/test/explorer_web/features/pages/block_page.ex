defmodule ExplorerWeb.BlockPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 2]

  alias Explorer.Chain.{Block, InternalTransaction}

  def contract_creation(%InternalTransaction{created_contract_address_hash: hash}) do
    css("[data-address-hash='#{hash}']", text: "Contract Creation")
  end

  def detail_number(%Block{number: block_number}) do
    css("[data-test='block_detail_number']", text: to_string(block_number))
  end

  def visit_page(session, %Block{number: block_number}) do
    visit(session, "/en/blocks/#{block_number}/transactions")
  end
end
