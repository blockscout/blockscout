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
        variant: EthereumJSONRPC.Parity
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
      transaction_hashes = ~w(0x196c2579f30077e8df0994e185d724331350c2bdb0f5d4e48b9e83f1e149cc28
         0x19eb948514a971bcd3ab737083bbdb32da233fff2ba70490bb0a36937a418006
         0x1a1039899fd07a5fd81faf2ec11ca24fc6023d486d4156095688a29b3bf06b7b
         0x1a942061ed6cf0736b194732bb6e1edfcbc50cc004e0cdad79335b3e40e23c9c
         0x1bdec995deaa0e5b53cc7a0b84eaff39da90f5e507fdb4360881ff31f824d918
         0x1c26758e003b0bc89ac7e3e6e87c6fc76dfb8d878dc530055e6a34f4d557cb1c
         0x1d592be82979bd1cc320eb70d4bb1d61226d78baa9e57e2a12b24345f81ce3bd
         0x1e57e7ce2941c6108e899f786fe339fa50ab053e47fbdcbf5979f475042c6dd8
         0x1ec1f9c31a0f43f7e684bfa20e422d7d8a343f81c517be1e30f149618ae306f2
         0x221aaf59f7a05702f0f53744b4fdb5f74e3c6fdade7324fda342cc1ebc73e01c)

      if json_rpc_named_arguments[:transport_options][:http] == EthereumJSONRPC.HTTP.Mox do
        EthereumJSONRPC.HTTP.Mox
        |> expect(:json_rpc, fn _url, _json, _options ->
          {:ok, %{body: "504 Gateway Timeout", status_code: 413}}
        end)
        |> expect(:json_rpc, fn _url, json, _options ->
          json_binary = IO.iodata_to_binary(json)

          refute json_binary =~ "0x221aaf59f7a05702f0f53744b4fdb5f74e3c6fdade7324fda342cc1ebc73e01c"
          assert json_binary =~ "0x1bdec995deaa0e5b53cc7a0b84eaff39da90f5e507fdb4360881ff31f824d918"

          body =
            0..4
            |> Enum.map(fn id ->
              %{
                jsonrpc: "2.0",
                id: id,
                result: %{
                  "trace" => [
                    %{
                      "type" => "create",
                      "action" => %{"from" => "0x", "gas" => "0x0", "init" => "0x", "value" => "0x0"},
                      "traceAddress" => "0x",
                      "result" => %{"address" => "0x", "code" => "0x", "gasUsed" => "0x0"}
                    }
                  ]
                }
              }
            end)
            |> Jason.encode!()

          {:ok, %{body: body, status_code: 200}}
        end)
        |> expect(:json_rpc, fn _url, json, _options ->
          json_binary = IO.iodata_to_binary(json)

          refute json_binary =~ "0x1bdec995deaa0e5b53cc7a0b84eaff39da90f5e507fdb4360881ff31f824d918"
          assert json_binary =~ "0x1c26758e003b0bc89ac7e3e6e87c6fc76dfb8d878dc530055e6a34f4d557cb1c"
          assert json_binary =~ "0x221aaf59f7a05702f0f53744b4fdb5f74e3c6fdade7324fda342cc1ebc73e01c"

          body =
            5..9
            |> Enum.map(fn id ->
              %{
                jsonrpc: "2.0",
                id: id,
                result: %{
                  "trace" => [
                    %{
                      "type" => "create",
                      "action" => %{"from" => "0x", "gas" => "0x0", "init" => "0x", "value" => "0x0"},
                      "traceAddress" => "0x",
                      "result" => %{"address" => "0x", "code" => "0x", "gasUsed" => "0x0"}
                    }
                  ]
                }
              }
            end)
            |> Jason.encode!()

          {:ok, %{body: body, status_code: 200}}
        end)
      end

      transactions_params =
        Enum.map(transaction_hashes, fn hash_data -> %{block_number: 0, hash_data: hash_data, gas: 1_000_000} end)

      assert {:ok, responses} =
               EthereumJSONRPC.fetch_internal_transactions(transactions_params, json_rpc_named_arguments)

      assert Enum.count(responses) == Enum.count(transactions_params)

      transaction_hash_set = MapSet.new(transaction_hashes)

      response_transaction_hash_set =
        Enum.into(responses, MapSet.new(), fn %{transaction_hash: transaction_hash} ->
          transaction_hash
        end)

      assert MapSet.equal?(response_transaction_hash_set, transaction_hash_set)
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
