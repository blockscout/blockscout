# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.HttpClient.TeslaHelperTest do
  use ExUnit.Case, async: true

  alias Utils.HttpClient.TeslaHelper

  describe "request_opts/1" do
    test "forwards max_body_length to the adapter as max_body" do
      [adapter: adapter_opts] = TeslaHelper.request_opts(max_body_length: 1024)

      assert adapter_opts[:max_body] == 1024
      assert adapter_opts[:protocols] == [:http1]
    end

    test "sets no body cap when max_body_length is absent" do
      [adapter: adapter_opts] = TeslaHelper.request_opts(recv_timeout: 1_000)

      refute Keyword.has_key?(adapter_opts, :max_body)
      assert adapter_opts[:timeout] == 1_000
    end
  end
end
