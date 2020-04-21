defmodule BlockScoutWeb.CommonComponentsView do
  use BlockScoutWeb, :view

  def balance_percentage_enabled?(total_supply) do
    Application.get_env(:block_scout_web, :show_percentage) && total_supply > 0
  end
end
