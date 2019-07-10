defmodule BlockScoutWeb.ApiDocsViewTest do
  use BlockScoutWeb.ConnCase, async: false

  alias BlockScoutWeb.{APIDocsView, Endpoint}

  describe "blockscout_url/0" do
    test "returns url with scheme and host without port" do
      Application.put_env(:block_scout_web, BlockScoutWeb.Endpoint,
        url: [scheme: "https", host: "blockscout.com", port: 9999, path: "/"]
      )

      assert APIDocsView.blockscout_url() == "https://blockscout.com/"
    end

    test "returns url with scheme and host with path" do
      System.put_env("BLOCKSCOUT_HOST", "blockscout.com")
      System.put_env("NETWORK_PATH", "/chain/dog")

      assert APIDocsView.blockscout_url() == "http://blockscout.com/chain/dog"
      assert Endpoint.url() == "http://blockscout.com:4002"

      System.put_env("NETWORK_PATH", "")
    end
  end
end
