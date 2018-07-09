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
        ]
      ]
    }
  end

  setup :verify_on_exit!

  describe "json_rpc/2" do
    # regression test for https://github.com/poanetwork/poa-explorer/issues/254
    #
    # this test triggered a DoS with CloudFlare reporting 502 Bad Gateway
    # (see https://github.com/poanetwork/poa-explorer/issues/340), so it can't be run against the real Sokol chain and
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
        |> expect(:json_rpc, fn _url, json, _optons ->
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
