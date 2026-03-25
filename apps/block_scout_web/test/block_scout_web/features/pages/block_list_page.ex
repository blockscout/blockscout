defmodule BlockScoutWeb.BlockListPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 2]

  alias Explorer.Chain.Block

  def visit_page(session) do
    visit(session, "/blocks")
  end

  def visit_reorgs_page(session) do
    visit(session, "/reorgs")
  end

  def visit_uncles_page(session) do
    visit(session, "/uncles?block_number=999999999")
  end

  def block(%Block{number: block_number}) do
    css("[data-block-number='#{block_number}']", visible: false)
  end

  def place_holder_blocks(count) do
    css("[data-selector='place-holder']", count: count, visible: false)
  end

  def blocks(count) do
    css("[data-selector='block-tile']", count: count, visible: false)
  end

  def uncle_blocks(count) do
    css("[data-selector='block-tile'].tile-type-uncle", count: count, visible: false)
  end
end
