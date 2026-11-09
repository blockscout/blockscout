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
  end
end
