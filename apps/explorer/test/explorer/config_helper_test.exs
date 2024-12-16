defmodule ConfigHelperTest do
  use ExUnit.Case

  setup do
    current_env_vars = System.get_env()
    clear_env_variables()

    on_exit(fn ->
      System.put_env(current_env_vars)
    end)
  end

  describe "parse_urls_list/3" do
    test "common case" do
      System.put_env("ETHEREUM_JSONRPC_HTTP_URLS", "test")
      assert ConfigHelper.parse_urls_list(:http) == ["test"]
    end

    test "using defined default" do
      System.put_env("ETHEREUM_JSONRPC_HTTP_URL", "test")
      refute System.get_env("ETHEREUM_JSONRPC_ETH_CALL_URLS")
      refute System.get_env("ETHEREUM_JSONRPC_ETH_CALL_URL")
      assert ConfigHelper.parse_urls_list(:eth_call) == ["test"]
    end

    test "using defined fallback default" do
      System.put_env("ETHEREUM_JSONRPC_FALLBACK_HTTP_URL", "test")
      refute System.get_env("ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URLS")
      refute System.get_env("ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URL")

      assert ConfigHelper.parse_urls_list(:fallback_eth_call) == ["test"]
    end

    test "base http urls are used if fallback is not provided" do
      System.put_env("ETHEREUM_JSONRPC_HTTP_URL", "test")
      refute System.get_env("ETHEREUM_JSONRPC_FALLBACK_TRACE_URLS")
      refute System.get_env("ETHEREUM_JSONRPC_FALLBACK_TRACE_URL")

      assert ConfigHelper.parse_urls_list(:fallback_trace) == ["test"]
    end
  end

  defp clear_env_variables do
    System.delete_env("ETHEREUM_JSONRPC_HTTP_URLS")
    System.delete_env("ETHEREUM_JSONRPC_HTTP_URL")
    System.delete_env("ETHEREUM_JSONRPC_TRACE_URLS")
    System.delete_env("ETHEREUM_JSONRPC_TRACE_URL")
    System.delete_env("ETHEREUM_JSONRPC_ETH_CALL_URLS")
    System.delete_env("ETHEREUM_JSONRPC_ETH_CALL_URL")
    System.delete_env("ETHEREUM_JSONRPC_FALLBACK_HTTP_URLS")
    System.delete_env("ETHEREUM_JSONRPC_FALLBACK_HTTP_URL")
    System.delete_env("ETHEREUM_JSONRPC_FALLBACK_TRACE_URLS")
    System.delete_env("ETHEREUM_JSONRPC_FALLBACK_TRACE_URL")
    System.delete_env("ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URLS")
    System.delete_env("ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URL")
  end
end
