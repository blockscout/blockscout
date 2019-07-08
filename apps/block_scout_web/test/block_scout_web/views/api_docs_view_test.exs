defmodule BlockScoutWeb.ApiDocsViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.{APIDocsView, Endpoint}

  describe "blockscout_url/0" do
    test "returns url with scheme and host without port" do
      System.put_env("BLOCKSCOUT_HOST", "localhost")

      assert APIDocsView.blockscout_url() == "http://localhost/"
      assert Endpoint.url() == "http://localhost:4002"
    end

    test "returns url with scheme and host with path" do
      System.put_env("BLOCKSCOUT_HOST", "localhost/chain/dog")
      System.put_env("NETWORK_PATH", "/chain/dog")

      assert APIDocsView.blockscout_url() == "http://localhost/chain/dog"
      assert Endpoint.url() == "http://localhost:4002"

      System.put_env("NETWORK_PATH", "")
    end
  end
end
