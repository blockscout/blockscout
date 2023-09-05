defmodule BlockScoutWeb.RobotsView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.APIDocsView
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Address

  @limit 200
  defp limit, do: @limit
end
