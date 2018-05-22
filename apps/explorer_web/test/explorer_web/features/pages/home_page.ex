defmodule ExplorerWeb.HomePage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  def blocks(count: count) do
    css("[data-test='chain_block']", count: count)
  end

  def search(session, text) do
    session
    |> fill_in(css("[data-test='search_input']"), with: text)
    |> send_keys([:enter])
  end

  def visit_page(session) do
    visit(session, "/")
  end

  def transactions(count: count) do
    css("[data-test='chain_transaction']", count: count)
  end
end
