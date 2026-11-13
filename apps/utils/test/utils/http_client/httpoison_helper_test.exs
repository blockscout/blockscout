# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.HttpClient.HTTPoisonHelperTest do
  use ExUnit.Case, async: true

  alias Utils.HttpClient.HTTPoisonHelper

  describe "request_opts/1" do
    test "forwards max_body_length to hackney as max_body_size" do
      opts = HTTPoisonHelper.request_opts(max_body_length: 1024)

      assert opts[:hackney] == [max_body_size: 1024]
    end

    test "keeps other hackney options alongside max_body_size" do
      opts = HTTPoisonHelper.request_opts(max_body_length: 1024, pool: :some_pool)

      assert Keyword.fetch!(opts[:hackney], :max_body_size) == 1024
      assert Keyword.fetch!(opts[:hackney], :pool) == :some_pool
    end

    test "sets no body cap when max_body_length is absent" do
      opts = HTTPoisonHelper.request_opts(recv_timeout: 1_000)

      refute Keyword.has_key?(opts, :hackney)
      assert opts[:recv_timeout] == 1_000
    end

    test "forwards hostname as the SNI ssl option" do
      opts = HTTPoisonHelper.request_opts(hostname: "example.com")

      assert opts[:ssl] == [server_name_indication: ~c"example.com"]
    end

    test "restricts a request with a hostname to HTTP/1.1" do
      # Over HTTP/2 hackney drops the `Host` header and derives `:authority` from the
      # connection host, which is the pinned IP literal.
      opts = HTTPoisonHelper.request_opts(hostname: "example.com", max_body_length: 1024)

      assert Keyword.fetch!(opts[:hackney], :protocols) == [:http1]
      assert Keyword.fetch!(opts[:hackney], :max_body_size) == 1024
    end

    test "keeps certificate verification disabled for an insecure request with a hostname" do
      # With `:ssl` set, HTTPoison merges hackney's `verify_peer` defaults into the ssl options
      # before hackney sees the `:insecure` flag, so the flag alone no longer disables them.
      opts = HTTPoisonHelper.request_opts(hostname: "example.com", insecure: true)

      assert Keyword.fetch!(opts[:ssl], :verify) == :verify_none
      assert :insecure in opts[:hackney]
    end

    test "trims the trailing dot of the hostname for SNI" do
      opts = HTTPoisonHelper.request_opts(hostname: "example.com.")

      assert opts[:ssl] == [server_name_indication: ~c"example.com"]
    end
  end
end
