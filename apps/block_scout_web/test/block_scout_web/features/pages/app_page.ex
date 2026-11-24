# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.AppPage do
  @moduledoc false

  use Fluffy.Assert

  import Fluffy
  import Fluffy.Locator

  def visit_page(session) do
    visit(session, "/")
  end

  def indexed_status(text) do
    filter(by_css("[data-selector='indexed-status'] [data-indexed-ratio]"), has_text: text)
  end

  def still_indexing?() do
    by_css("[data-selector='indexed-status']")
  end
end
