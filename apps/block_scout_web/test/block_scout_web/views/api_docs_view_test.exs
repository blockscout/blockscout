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
end
