defmodule ExplorerWeb.HomePage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.InternalTransaction

  def blocks(count: count) do
    css("[data-test='chain_block']", count: count)
  end

  def contract_creation(%InternalTransaction{created_contract_address_hash: hash}) do
    css("[data-address-hash='#{hash}']", text: "Contract Creation")
  end

  def search(session, text) do
    session
    |> fill_in(css("[data-test='search_input']"), with: text)
    |> send_keys([:enter])
  end

  def transactions(count: count) do
    css("[data-test='chain_transaction']", count: count)
  end

  def visit_page(session) do
    visit(session, "/")
  end
end
