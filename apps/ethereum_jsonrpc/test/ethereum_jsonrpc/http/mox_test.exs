defmodule EthereumJSONRPC.HTTP.MoxTest do
  @moduledoc """
  Tests differences in behavior of `EthereumJSONRPC` when `EthereumJSONRPC.HTTP` is used as the transport that are too
  detrimental to run against Sokol, so uses `EthereumJSONRPC.HTTP.Mox` instead.
  """

  use ExUnit.Case, async: true

  import EthereumJSONRPC, only: [request: 1]
  import EthereumJSONRPC.HTTP.Case
  import Mox

  setup do
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          http: EthereumJSONRPC.HTTP.Mox,
          url: url(),
          http_options: http_options()
        ],
        # Which one does not matter, so pick one
        variant: EthereumJSONRPC.Nethermind
      ]
    }
  end

  setup :verify_on_exit!

  describe "json_rpc/2" do
    # regression test for https://github.com/poanetwork/blockscout/issues/254
    #
    # this test triggered a DoS with CloudFlare reporting 502 Bad Gateway
    # (see https://github.com/poanetwork/blockscout/issues/340), so it can't be run against the real Sokol chain and
    # must use `mox` to fake it.
    test "transparently splits batch payloads that would trigger a 413 Request Entity Too Large", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport_options][:http] == EthereumJSONRPC.HTTP.Mox do
        EthereumJSONRPC.HTTP.Mox
        |> expect(:json_rpc, 2, fn _url, json, _options ->
          assert IO.iodata_to_binary(json) =~ ":13000"

          {:ok, %{body: "413 Request Entity Too Large", status_code: 413}}
        end)
        |> expect(:json_rpc, fn _url, json, _options ->
          json_binary = IO.iodata_to_binary(json)

          refute json_binary =~ ":13000"
          assert json_binary =~ ":6499"

          body =
            0..6499
            |> Enum.map(fn id ->
              %{jsonrpc: "2.0", id: id, result: %{number: EthereumJSONRPC.integer_to_quantity(id)}}
            end)
            |> Jason.encode!()

          {:ok, %{body: body, status_code: 200}}
        end)
        |> expect(:json_rpc, fn _url, json, _options ->
          json_binary = IO.iodata_to_binary(json)

          refute json_binary =~ ":6499"
          assert json_binary =~ ":6500"
          assert json_binary =~ ":13000"

          body =
            6500..13000
            |> Enum.map(fn id ->
              %{jsonrpc: "2.0", id: id, result: %{number: EthereumJSONRPC.integer_to_quantity(id)}}
            end)
            |> Jason.encode!()

          {:ok, %{body: body, status_code: 200}}
        end)
      end

      block_numbers = 0..13000

      payload =
        block_numbers
        |> Stream.with_index()
        |> Enum.map(&get_block_by_number_request/1)

      assert_payload_too_large(payload, json_rpc_named_arguments)

      assert {:ok, responses} = EthereumJSONRPC.json_rpc(payload, json_rpc_named_arguments)
      assert Enum.count(responses) == Enum.count(block_numbers)

      block_number_set = MapSet.new(block_numbers)

      response_block_number_set =
        Enum.into(responses, MapSet.new(), fn %{result: %{"number" => quantity}} ->
          EthereumJSONRPC.quantity_to_integer(quantity)
        end)

      assert MapSet.equal?(response_block_number_set, block_number_set)
    end

    @tag :no_geth
    # Regression test for https://github.com/poanetwork/blockscout/issues/418
    test "transparently splits batch payloads that would trigger a 504 Gateway Timeout", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_numbers = [862_272, 862_273, 862_274, 862_275, 862_276, 862_277, 862_278, 862_279, 862_280, 862_281]

      if json_rpc_named_arguments[:transport_options][:http] == EthereumJSONRPC.HTTP.Mox do
        EthereumJSONRPC.HTTP.Mox
        |> expect(:json_rpc, fn _url, _json, _options ->
          {:ok, %{body: "504 Gateway Timeout", status_code: 504}}
        end)
        |> expect(:json_rpc, fn _url, json, _options ->
          json_binary = IO.iodata_to_binary(json)

          refute json_binary =~ "0xD2849"
          assert json_binary =~ "0xD2844"

          body =
            0..4
            |> Enum.map(fn id ->
              %{
                jsonrpc: "2.0",
                id: id,
                result: [
                  %{
                    "trace" => [
                      %{
                        "type" => "create",
                        "action" => %{"from" => "0x", "gas" => "0x0", "init" => "0x", "value" => "0x0"},
                        "traceAddress" => "0x",
                        "result" => %{"address" => "0x", "code" => "0x", "gasUsed" => "0x0"}
                      }
                    ],
                    "transactionHash" => "0x221aaf59f7a05702f0f53744b4fdb5f74e3c6fdade7324fda342cc1ebc73e01c"
                  }
                ]
              }
            end)
            |> Jason.encode!()

          {:ok, %{body: body, status_code: 200}}
        end)
        |> expect(:json_rpc, fn _url, json, _options ->
          json_binary = IO.iodata_to_binary(json)

          refute json_binary =~ "0xD2844"
          assert json_binary =~ "0xD2845"
          assert json_binary =~ "0xD2849"

          body =
            5..9
            |> Enum.map(fn id ->
              %{
                jsonrpc: "2.0",
                id: id,
                result: [
                  %{
                    "trace" => [
                      %{
                        "type" => "create",
                        "action" => %{"from" => "0x", "gas" => "0x0", "init" => "0x", "value" => "0x0"},
                        "traceAddress" => "0x",
                        "result" => %{"address" => "0x", "code" => "0x", "gasUsed" => "0x0"}
                      }
                    ],
                    "transactionHash" => "0x221aaf59f7a05702f0f53744b4fdb5f74e3c6fdade7324fda342cc1ebc73e01c"
                  }
                ]
              }
            end)
            |> Jason.encode!()

          {:ok, %{body: body, status_code: 200}}
        end)
      end

      assert {:ok, responses} =
               EthereumJSONRPC.fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments)

      assert Enum.count(responses) == Enum.count(block_numbers)

      block_number_set = MapSet.new(block_numbers)

      response_block_number_set =
        Enum.into(responses, MapSet.new(), fn %{block_number: block_number} ->
          block_number
        end)

      assert MapSet.equal?(response_block_number_set, block_number_set)
    end

    @tag :no_geth
    # Regression test for https://github.com/poanetwork/blockscout/issues/418
    test "transparently splits batch payloads that would trigger a request timeout", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_numbers = [862_272, 862_273, 862_274, 862_275, 862_276, 862_277, 862_278, 862_279, 862_280, 862_281]

      if json_rpc_named_arguments[:transport_options][:http] == EthereumJSONRPC.HTTP.Mox do
        EthereumJSONRPC.HTTP.Mox
        |> expect(:json_rpc, fn _url, _json, _options ->
          {:error, :timeout}
        end)
        |> expect(:json_rpc, fn _url, json, _options ->
          json_binary = IO.iodata_to_binary(json)

          refute json_binary =~ "0xD2849"
          assert json_binary =~ "0xD2844"

          body =
            0..4
            |> Enum.map(fn id ->
              %{
                jsonrpc: "2.0",
                id: id,
                result: [
                  %{
                    "trace" => [
                      %{
                        "type" => "create",
                        "action" => %{"from" => "0x", "gas" => "0x0", "init" => "0x", "value" => "0x0"},
                        "traceAddress" => "0x",
                        "result" => %{"address" => "0x", "code" => "0x", "gasUsed" => "0x0"}
                      }
                    ],
                    "transactionHash" => "0x221aaf59f7a05702f0f53744b4fdb5f74e3c6fdade7324fda342cc1ebc73e01c"
                  }
                ]
              }
            end)
            |> Jason.encode!()

          {:ok, %{body: body, status_code: 200}}
        end)
        |> expect(:json_rpc, fn _url, json, _options ->
          json_binary = IO.iodata_to_binary(json)

          refute json_binary =~ "0xD2844"
          assert json_binary =~ "0xD2845"
          assert json_binary =~ "0xD2849"

          body =
            5..9
            |> Enum.map(fn id ->
              %{
                jsonrpc: "2.0",
                id: id,
                result: [
                  %{
                    "trace" => [
                      %{
                        "type" => "create",
                        "action" => %{"from" => "0x", "gas" => "0x0", "init" => "0x", "value" => "0x0"},
                        "traceAddress" => "0x",
                        "result" => %{"address" => "0x", "code" => "0x", "gasUsed" => "0x0"}
                      }
                    ],
                    "transactionHash" => "0x221aaf59f7a05702f0f53744b4fdb5f74e3c6fdade7324fda342cc1ebc73e01c"
                  }
                ]
              }
            end)
            |> Jason.encode!()

          {:ok, %{body: body, status_code: 200}}
        end)
      end

      assert {:ok, responses} =
               EthereumJSONRPC.fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments)

      assert Enum.count(responses) == Enum.count(block_numbers)

      block_number_set = MapSet.new(block_numbers)

      response_block_number_set =
        Enum.into(responses, MapSet.new(), fn %{block_number: block_number} ->
          block_number
        end)

      assert MapSet.equal?(response_block_number_set, block_number_set)
    end
  end

  defp assert_payload_too_large(payload, json_rpc_named_arguments) do
    assert Keyword.fetch!(json_rpc_named_arguments, :transport) == EthereumJSONRPC.HTTP

    transport_options = Keyword.fetch!(json_rpc_named_arguments, :transport_options)

    http = Keyword.fetch!(transport_options, :http)
    url = Keyword.fetch!(transport_options, :url)
    json = Jason.encode_to_iodata!(payload)
    http_options = Keyword.fetch!(transport_options, :http_options)

    assert {:ok, %{body: body, status_code: 413}} = http.json_rpc(url, json, http_options)
    assert body =~ "413 Request Entity Too Large"
  end

  defp get_block_by_number_request({block_number, id}) do
    request(%{
      id: id,
      method: "eth_getBlockByNumber",
      params: [EthereumJSONRPC.integer_to_quantity(block_number), true]
    })
  end
end
