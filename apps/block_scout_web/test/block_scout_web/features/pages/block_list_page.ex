defmodule BlockScoutWeb.BlockListPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1]

  alias Explorer.Chain.Block

  def visit_page(session) do
    visit(session, "/en/blocks")
  end

  def block(%Block{number: block_number}) do
    css("[data-test='block_number'][data-block-number='#{block_number}']")
  end
end
