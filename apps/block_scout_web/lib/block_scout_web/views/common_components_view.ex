defmodule BlockScoutWeb.CommonComponentsView do
  use BlockScoutWeb, :view

  def balance_percentage_enabled? do
    Application.get_env(:block_scout_web, :show_percentage)
  end
end
