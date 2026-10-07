# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.TokenInstanceHelperTest do
  use ExUnit.Case, async: false

  alias Utils.TokenInstanceHelper

  setup do
    previous = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)

    Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper,
      host_filtering_enabled?: true,
      cidr_blacklist: [],
      allowed_uri_protocols: ["http", "https"]
    )

    :persistent_term.erase(:parsed_cidr_list)

    bypass = Bypass.open()

    on_exit(fn ->
      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper, previous)
      :persistent_term.erase(:parsed_cidr_list)
    end)

    {:ok, bypass: bypass}
  end

  # Bypass listens on 127.0.0.1, which is blacklisted. That is exactly the shape of an
  # operator-hosted IPFS/Arweave/Swarm gateway on a private address: the host is trusted
  # configuration rather than on-chain data, so it must stay fetchable.
  describe "media_type/4" do
    test "blocks a private host when the URL comes from on-chain metadata", %{bypass: bypass} do
      Bypass.stub(bypass, "HEAD", "/media", fn conn ->
        conn |> Plug.Conn.put_resp_header("content-type", "image/jpeg") |> Plug.Conn.resp(200, "")
      end)

      assert TokenInstanceHelper.media_type("http://127.0.0.1:#{bypass.port}/media", [], false, true) == nil
    end

    test "allows a private host when the URL was resolved to an operator gateway", %{bypass: bypass} do
      Bypass.stub(bypass, "HEAD", "/media", fn conn ->
        conn |> Plug.Conn.put_resp_header("content-type", "image/jpeg") |> Plug.Conn.resp(200, "")
      end)

      assert TokenInstanceHelper.media_type("http://127.0.0.1:#{bypass.port}/media", [], false, false) ==
               {"image", "jpeg"}
    end

    test "does not issue a request for an extension-less value that is not an http(s) URL", %{bypass: bypass} do
      Bypass.stub(bypass, "HEAD", "/media", fn _conn -> flunk("unexpected HEAD request") end)

      for url <- ["image_url0", "media/image_url0", "ftp://127.0.0.1:#{bypass.port}/media", "http:///media"] do
        assert TokenInstanceHelper.media_type(url, [], false, false) == nil
      end
    end
  end

  describe "media_type_detailed/3" do
    test "blocks a private host by default", %{bypass: bypass} do
      Bypass.stub(bypass, "HEAD", "/media", fn conn ->
        conn |> Plug.Conn.put_resp_header("content-type", "image/jpeg") |> Plug.Conn.resp(200, "")
      end)

      assert {:error, reason} = TokenInstanceHelper.media_type_detailed("http://127.0.0.1:#{bypass.port}/media", [])
      assert reason =~ "blacklist"
    end

    test "allows a private host when host validation is waived", %{bypass: bypass} do
      Bypass.stub(bypass, "HEAD", "/media", fn conn ->
        conn |> Plug.Conn.put_resp_header("content-type", "image/jpeg") |> Plug.Conn.resp(200, "")
      end)

      assert TokenInstanceHelper.media_type_detailed("http://127.0.0.1:#{bypass.port}/media", [], false) ==
               {:ok, {"image", "jpeg"}}
    end

    test "reports an extension-less value that is not an http(s) URL without a request", %{bypass: bypass} do
      Bypass.stub(bypass, "HEAD", "/media", fn _conn -> flunk("unexpected HEAD request") end)

      for url <- ["image_url0", "media/image_url0", "ftp://127.0.0.1:#{bypass.port}/media"] do
        assert {:error, reason} = TokenInstanceHelper.media_type_detailed(url, [], false)
        assert reason =~ "not an http(s) URL"
      end
    end

    test "still resolves the media type from the extension of a non-web URL" do
      assert TokenInstanceHelper.media_type_detailed("image_url0.png", [], false) == {:ok, {"image", "png"}}
    end
  end
end
