defmodule BlockScoutWeb.ChainView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.LayoutView

  def network_dashboard_graph do
    Keyword.get(application_config(), :network_dashboard_graph) || true
  end

  defp application_config do
    Application.get_env(:block_scout_web, BlockScoutWeb.Chain)
  end
end
