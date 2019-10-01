defmodule BlockScoutWeb.StakesView do
  use BlockScoutWeb, :view
  import BlockScoutWeb.StakesHelpers

  def render("styles.html", _) do
    ~E(<link rel="stylesheet" href="/css/stakes.css">)
  end
end
