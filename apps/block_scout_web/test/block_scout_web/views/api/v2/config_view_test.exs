defmodule BlockScoutWeb.API.V2.ConfigViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.ConfigView

  test "renders backend_version.json" do
    result = ConfigView.render("backend_version.json", %{version: "1.2.3"})

    assert result == %{"backend_version" => "1.2.3"}
  end
end
