defmodule BlockScoutWeb.API.V2.ConfigControllerTest do
  use BlockScoutWeb.ConnCase

  describe "/config/backend-version" do
    test "get json rps url if set", %{conn: conn} do
      version = "v6.3.0-beta"
      Application.put_env(:block_scout_web, :version, version)

      request = get(conn, "/api/v2/config/backend-version")

      assert %{"backend_version" => ^version} = json_response(request, 200)
    end

    test "get nil backend version if not set", %{conn: conn} do
      Application.put_env(:block_scout_web, :version, nil)

      request = get(conn, "/api/v2/config/backend-version")

      assert %{"backend_version" => nil} = json_response(request, 200)
    end
  end
end
