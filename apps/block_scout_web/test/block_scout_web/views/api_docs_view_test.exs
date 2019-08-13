defmodule BlockScoutWeb.ApiDocsViewTest do
  use BlockScoutWeb.ConnCase, async: false

  alias BlockScoutWeb.APIDocsView

  describe "blockscout_url/0" do
    setup do
      original = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)

      on_exit(fn -> Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint, original) end)

      :ok
    end

    test "returns url with scheme and host without port" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, path: "/"]
      )

      assert APIDocsView.blockscout_url() == "https://blockscout.com/"
    end

    test "returns url with scheme and host with path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, path: "/chain/dog"]
      )

      assert APIDocsView.blockscout_url() == "https://blockscout.com/chain/dog"
    end
  end

  describe "api_url/1" do
    test "adds slash before path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, path: "/chain/dog"]
      )

      assert APIDocsView.api_url() == "https://blockscout.com/chain/dog/api"
    end

    test "does not add slash to empty path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, path: ""]
      )

      assert APIDocsView.api_url() == "https://blockscout.com/api"
    end
  end

  describe "eth_rpc_api_url/1" do
    test "adds slash before path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, path: "/chain/dog"]
      )

      assert APIDocsView.eth_rpc_api_url() == "https://blockscout.com/chain/dog/api/eth_rpc"
    end

    test "does not add slash to empty path" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, path: ""]
      )

      assert APIDocsView.eth_rpc_api_url() == "https://blockscout.com/api/eth_rpc"
    end
  end
end
