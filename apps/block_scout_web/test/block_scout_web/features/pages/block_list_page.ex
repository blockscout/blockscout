defmodule BlockScoutWeb.BlockListPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  alias Explorer.Chain.Block

  def visit_page(session) do
    visit(session, "/blocks")
  end

  def block(%Block{number: block_number}) do
    css("[data-block-number='#{block_number}']")
  end

  def place_holder_blocks(count) do
    css("[data-selector='place-holder']", count: count)
  end
end
