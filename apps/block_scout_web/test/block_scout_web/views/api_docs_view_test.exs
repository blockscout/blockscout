defmodule BlockScoutWeb.ApiDocsViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.{APIDocsView, Endpoint}

  describe "blockscout_url/0" do
    test "returns url with scheme and host without port" do
      System.put_env("BLOCKSCOUT_HOST", "localhost")

      assert APIDocsView.blockscout_url() == "http://localhost"
      assert Endpoint.url() == "http://localhost:4002"
    end
  end
end
