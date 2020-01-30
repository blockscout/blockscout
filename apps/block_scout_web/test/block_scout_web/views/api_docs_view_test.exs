defmodule BlockScoutWeb.ApiDocsViewTest do
  use BlockScoutWeb.ConnCase, async: false

  alias BlockScoutWeb.APIDocsView

  describe "api_url/1" do
    setup do
      original = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)

      on_exit(fn -> Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint, original) end)

      :ok
    end

    test "adds slash before path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, api_path: "/chain/dog"]
      )

      assert APIDocsView.api_url() == "https://blockscout.com/chain/dog/api"
    end

    test "does not add slash to empty path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, api_path: ""]
      )

      assert APIDocsView.api_url() == "https://blockscout.com/api"
    end

    test "localhost return with port" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "http", host: "localhost"],
        http: [port: 9999]
      )

      assert APIDocsView.api_url() == "http://localhost:9999/api"
    end
  end

  describe "eth_rpc_api_url/1" do
    setup do
      original = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)

      on_exit(fn -> Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint, original) end)

      :ok
    end

    test "adds slash before path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, api_path: "/chain/dog"]
      )

      assert APIDocsView.eth_rpc_api_url() == "https://blockscout.com/chain/dog/api/eth_rpc"
    end

    test "does not add slash to empty path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, path: ""]
      )

      assert APIDocsView.eth_rpc_api_url() == "https://blockscout.com/api/eth_rpc"
    end

    test "localhost return with port" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "http", host: "localhost"],
        http: [port: 9999]
      )

      assert APIDocsView.eth_rpc_api_url() == "http://localhost:9999/api/eth_rpc"
    end
  end
end
