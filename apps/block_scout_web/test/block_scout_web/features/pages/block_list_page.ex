# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.BlockListPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  alias Explorer.Chain.Block

  def visit_page(session) do
    visit(session, "/blocks")
  end

  def visit_reorgs_page(session) do
    visit(session, "/reorgs")
  end

  def visit_uncles_page(session) do
    visit(session, "/uncles")
  end

  def block(%Block{number: block_number}) do
    by_css("[data-block-number='#{block_number}']")
  end

  def place_holder_blocks(count) do
    count(filter(by_css("[data-selector='place-holder']"), visible: true), count)
  end

  def blocks(count) do
    count(filter(by_css("[data-selector='block-tile']"), visible: true), count)
  end
end
