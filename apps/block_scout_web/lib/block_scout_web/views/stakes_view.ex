defmodule BlockScoutWeb.StakesView do
  use BlockScoutWeb, :view
  import BlockScoutWeb.StakesHelpers

  def render("scripts.html", %{conn: conn}) do
    render_scripts(conn, "stakes.js")
  end

  def render("styles.html", _) do
    ~E(<link rel="stylesheet" href="/css/stakes.css">)
  end
end
