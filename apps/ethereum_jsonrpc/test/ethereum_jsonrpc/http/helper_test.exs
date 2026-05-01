defmodule EthereumJSONRPC.HTTP.HelperTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.HTTP.Helper

  describe "heavy_request_method?/1" do
    test "returns true for trace methods" do
      assert Helper.heavy_request_method?("trace_block")
    end

    test "returns true for debug methods" do
      assert Helper.heavy_request_method?("debug_traceTransaction")
    end

    test "returns true for eth_getBlockReceipts" do
      assert Helper.heavy_request_method?("eth_getBlockReceipts")
    end

    test "returns false for non-heavy methods" do
      refute Helper.heavy_request_method?("eth_getBlockByNumber")
      refute Helper.heavy_request_method?(nil)
      refute Helper.heavy_request_method?({:error, :invalid_json})
    end
  end

  describe "request_compression_enabled?/2" do
    test "enables compression for heavy methods by default" do
      config = [request_compression_heavy_methods_enabled?: true, request_compression_all_methods_enabled?: false]

      assert Helper.request_compression_enabled?("trace_block", config)
      assert Helper.request_compression_enabled?("debug_traceBlockByNumber", config)
      assert Helper.request_compression_enabled?("eth_getBlockReceipts", config)
    end

    test "does not enable non-heavy methods by default" do
      config = [request_compression_heavy_methods_enabled?: true, request_compression_all_methods_enabled?: false]

      refute Helper.request_compression_enabled?("eth_blockNumber", config)
    end

    test "enables all methods when all-methods flag is enabled" do
      config = [request_compression_heavy_methods_enabled?: false, request_compression_all_methods_enabled?: true]

      assert Helper.request_compression_enabled?("eth_blockNumber", config)
      assert Helper.request_compression_enabled?("trace_block", config)
    end

    test "disables all methods when both flags are disabled" do
      config = [request_compression_heavy_methods_enabled?: false, request_compression_all_methods_enabled?: false]

      refute Helper.request_compression_enabled?("eth_blockNumber", config)
      refute Helper.request_compression_enabled?("trace_block", config)
    end
  end
end
