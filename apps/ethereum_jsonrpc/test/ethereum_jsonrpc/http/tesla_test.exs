defmodule EthereumJSONRPC.HTTP.TeslaTest do
  use ExUnit.Case, async: false

  import Mox

  alias EthereumJSONRPC.HTTP.Tesla

  setup :verify_on_exit!

  setup do
    original_http_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP, [])
    original_tesla_adapter = Application.get_env(:tesla, :adapter)

    Application.put_env(:tesla, :adapter, EthereumJSONRPC.TeslaAdapter.Mox)

    on_exit(fn ->
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP, original_http_config)
      Application.put_env(:tesla, :adapter, original_tesla_adapter)
    end)

    :ok
  end

  describe "json_rpc/4 request compression" do
    test "compresses request body for heavy methods by default" do
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP,
        request_compression_heavy_methods_enabled?: true,
        request_compression_all_methods_enabled?: false,
        gzip_enabled?: false
      )

      response_body = ~s({"jsonrpc":"2.0","id":1,"result":"0x1"})
      url = "http://example.com"
      json = ~s({"jsonrpc":"2.0","id":1,"method":"debug_traceTransaction","params":["0xabc",{}]})

      EthereumJSONRPC.TeslaAdapter.Mox
      |> expect(:call, fn %Elixir.Tesla.Env{} = env, _opts ->
        assert env.url == url
        assert header_value(env.headers, "content-encoding") == "gzip"
        assert header_value(env.headers, "accept-encoding") == "gzip, deflate, identity"

        assert :zlib.gunzip(env.body) == json

        {:ok,
         %Elixir.Tesla.Env{
           env
           | status: 200,
             body: response_body,
             headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:ok, %{status_code: 200, body: ^response_body}} = Tesla.json_rpc(url, json, [], [])
    end

    test "does not compress non-heavy method when all-methods flag is disabled" do
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP,
        request_compression_heavy_methods_enabled?: true,
        request_compression_all_methods_enabled?: false,
        gzip_enabled?: false
      )

      response_body = ~s({"jsonrpc":"2.0","id":1,"result":"0x10"})
      url = "http://example.com"
      json = ~s({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]})

      EthereumJSONRPC.TeslaAdapter.Mox
      |> expect(:call, fn %Elixir.Tesla.Env{} = env, _opts ->
        assert env.url == url
        refute header_value(env.headers, "content-encoding")
        refute header_value(env.headers, "accept-encoding")
        assert env.body == json

        {:ok,
         %Elixir.Tesla.Env{
           env
           | status: 200,
             body: response_body,
             headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:ok, %{status_code: 200, body: ^response_body}} = Tesla.json_rpc(url, json, [], [])
    end

    test "compresses non-heavy method when all-methods flag is enabled" do
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.HTTP,
        request_compression_heavy_methods_enabled?: false,
        request_compression_all_methods_enabled?: true,
        gzip_enabled?: false
      )

      response_body = ~s({"jsonrpc":"2.0","id":1,"result":"0x10"})
      url = "http://example.com"
      json = ~s({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]})

      EthereumJSONRPC.TeslaAdapter.Mox
      |> expect(:call, fn %Elixir.Tesla.Env{} = env, _opts ->
        assert env.url == url
        assert header_value(env.headers, "content-encoding") == "gzip"
        assert header_value(env.headers, "accept-encoding") == "gzip, deflate, identity"
        assert :zlib.gunzip(env.body) == json

        {:ok,
         %Elixir.Tesla.Env{
           env
           | status: 200,
             body: response_body,
             headers: [{"content-type", "application/json"}]
         }}
      end)

      assert {:ok, %{status_code: 200, body: ^response_body}} = Tesla.json_rpc(url, json, [], [])
    end
  end

  defp header_value(headers, key) do
    normalized_key = String.downcase(key)

    headers
    |> Enum.find_value(fn {header_key, header_value} ->
      if String.downcase(header_key) == normalized_key do
        header_value
      end
    end)
  end
end
