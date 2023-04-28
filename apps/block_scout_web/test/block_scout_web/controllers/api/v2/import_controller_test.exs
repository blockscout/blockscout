defmodule BlockScoutWeb.API.V2.ImportControllerTest do
  use BlockScoutWeb.ConnCase

  describe "/import/token-info" do
    test "return error on misconfigured api key", %{conn: conn} do
      request = post(conn, "/api/v2/import/token-info", %{"iconUrl" => "abc", "tokenAddress" => build(:address).hash})

      assert %{"message" => "API key not configured on the server"} = json_response(request, 403)
    end

    test "return error on wrong api key", %{conn: conn} do
      Application.put_env(:block_scout_web, :sensitive_endpoints_api_key, "abc")
      body = %{"iconUrl" => "abc", "tokenAddress" => build(:address).hash}
      request = post(conn, "/api/v2/import/token-info", Map.merge(body, %{"api_key" => "123"}))

      assert %{"message" => "Wrong API key"} = json_response(request, 401)

      Application.put_env(:block_scout_web, :sensitive_endpoints_api_key, nil)
    end

    test "do not import token info with wrong url", %{conn: conn} do
      api_key = "abc123"
      icon_url = "icon_url"

      Application.put_env(:block_scout_web, :sensitive_endpoints_api_key, api_key)

      token_address = to_string(insert(:token).contract_address_hash)

      body = %{"iconUrl" => icon_url, "tokenAddress" => token_address}

      request = post(conn, "/api/v2/import/token-info", Map.merge(body, %{"api_key" => api_key}))
      assert %{"message" => "Invalid URL"} = json_response(request, 422)

      request = get(conn, "/api/v2/tokens/#{token_address}")
      assert %{"icon_url" => nil} = json_response(request, 200)

      Application.put_env(:block_scout_web, :sensitive_endpoints_api_key, nil)
    end

    test "success import token info", %{conn: conn} do
      api_key = "abc123"
      icon_url = "http://example.com/image?a=0&b=1"

      Application.put_env(:block_scout_web, :sensitive_endpoints_api_key, api_key)

      token_address = to_string(insert(:token).contract_address_hash)

      body = %{"iconUrl" => icon_url, "tokenAddress" => token_address}

      request = post(conn, "/api/v2/import/token-info", Map.merge(body, %{"api_key" => api_key}))
      assert %{"message" => "Success"} = json_response(request, 200)

      request = get(conn, "/api/v2/tokens/#{token_address}")
      assert %{"icon_url" => ^icon_url} = json_response(request, 200)

      Application.put_env(:block_scout_web, :sensitive_endpoints_api_key, nil)
    end
  end
end
