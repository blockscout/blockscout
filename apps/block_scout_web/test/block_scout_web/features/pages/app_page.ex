defmodule BlockScoutWeb.AppPage do
  @moduledoc false

  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  def visit_page(session) do
    visit(session, "/")
  end

  def indexed_status(text) do
    css("[data-selector='indexed-status'] [data-indexed-ratio]", text: text)
  end

  def still_indexing?() do
    css("[data-selector='indexed-status']")
  end
end
