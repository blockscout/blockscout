defmodule BlockScoutWeb.API.V2.ConfigControllerTest do
  use BlockScoutWeb.ConnCase

  describe "/config/json-rpc-url" do
    test "get json rps url if set", %{conn: conn} do
      url = "http://rps.url:1234/v1"
      Application.put_env(:block_scout_web, :json_rpc, url)

      request = get(conn, "/api/v2/config/json-rpc-url")

      assert %{"json_rpc_url" => ^url} = json_response(request, 200)
    end

    test "get empty json rps url if not set", %{conn: conn} do
      Application.put_env(:block_scout_web, :json_rpc, nil)

      request = get(conn, "/api/v2/config/json-rpc-url")

      assert %{"json_rpc_url" => nil} = json_response(request, 200)
    end
  end
end
