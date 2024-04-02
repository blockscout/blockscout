defmodule BlockScoutWeb.API.V2.ConfigView do
  def render("backend_version.json", %{version: version}) do
    %{
      "backend_version" => version
    }
  end
end
