# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.EthRPCTest do
  # the tested requests are proxied to the node, so no database is involved
  use ExUnit.Case, async: false

  import Mox

  alias Explorer.EthRPC

  setup :verify_on_exit!
  setup :set_mox_global

  @address_hash "0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F"

  describe "responses/1" do
    test "matches responses of a batch to the requests by id, not by their order" do
      requests = [
        %{
          "jsonrpc" => "2.0",
          "id" => "storage",
          "method" => "eth_getStorageAt",
          "params" => [@address_hash, "0x0", "latest"]
        },
        %{
          "jsonrpc" => "2.0",
          "id" => "call",
          "method" => "eth_call",
          "params" => [%{"to" => @address_hash, "input" => "0xd4aae0c4"}, "latest"]
        }
      ]

      # the node is free to respond in any order, and `EthereumJSONRPC.HTTP` splits a batch
      # by the url type its methods are mapped to, so the responses are reversed here
      expect(EthereumJSONRPC.Mox, :json_rpc, fn batch, _options ->
        assert [%{method: "eth_getStorageAt"}, %{method: "eth_call"}] = batch

        responses =
          Enum.map(batch, fn
            %{id: id, method: "eth_getStorageAt"} -> %{jsonrpc: "2.0", id: id, result: "0x123"}
            %{id: id, method: "eth_call"} -> %{jsonrpc: "2.0", id: id, result: "0x234"}
          end)

        {:ok, Enum.reverse(responses)}
      end)

      assert [
               %{id: "storage", result: "0x123"},
               %{id: "call", result: "0x234"}
             ] = EthRPC.responses(requests)
    end

    test "matches responses of a batch with duplicated user ids" do
      request = fn id, storage_pointer ->
        %{
          "jsonrpc" => "2.0",
          "id" => id,
          "method" => "eth_getStorageAt",
          "params" => [@address_hash, storage_pointer, "latest"]
        }
      end

      expect(EthereumJSONRPC.Mox, :json_rpc, fn batch, _options ->
        responses =
          Enum.map(batch, fn %{id: id, params: [_, storage_pointer, _]} ->
            %{jsonrpc: "2.0", id: id, result: storage_pointer}
          end)

        {:ok, Enum.reverse(responses)}
      end)

      assert [
               %{id: 1, result: "0x0"},
               %{id: 1, result: "0x1"}
             ] = EthRPC.responses([request.(1, "0x0"), request.(1, "0x1")])
    end
  end
end
