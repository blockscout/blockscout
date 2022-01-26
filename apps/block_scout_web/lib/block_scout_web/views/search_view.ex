defmodule BlockScoutWeb.SearchView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.AddressView
  alias Explorer.Chain
  alias Floki

  def highlight_search_result(result, query) do
    re = ~r/#{query}/i

    re
    |> Regex.replace(result, "<mark class=\'autoComplete_highlight\'>\\g{0}</mark>", global: true)
    |> raw()
  end
end
