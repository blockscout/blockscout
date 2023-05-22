defmodule BlockScoutWeb.SearchView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Floki

  def highlight_search_result(result, query) do
    re = ~r/#{query}/i

    safe_result =
      result
      |> html_escape()
      |> safe_to_string()

    re
    |> Regex.replace(safe_result, "<mark class=\'autoComplete_highlight\'>\\g{0}</mark>", global: true)
    |> raw()
  end
end
