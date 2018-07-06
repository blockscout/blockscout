defmodule EthereumJSONRPCTest do
  use ExUnit.Case, async: true

  alias Plug.Conn

  doctest EthereumJSONRPC

  describe "fetch_balances/1" do
    test "with all valid hash_data returns {:ok, addresses_params}" do
      assert EthereumJSONRPC.fetch_balances([
               %{block_quantity: "0x1", hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}
             ]) ==
               {:ok,
                [
                  %{
                    fetched_balance: 1,
                    fetched_balance_block_number: 1,
                    hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                  }
                ]}
    end

    test "with all invalid hash_data returns {:error, reasons}" do
      assert EthereumJSONRPC.fetch_balances([%{block_quantity: "0x1", hash_data: "0x0"}]) ==
               {:error,
                [
                  %{
                    "blockNumber" => "0x1",
                    "code" => -32602,
                    "hash" => "0x0",
                    "message" =>
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  }
                ]}
    end

    test "with a mix of valid and invalid hash_data returns {:error, reasons}" do
      assert EthereumJSONRPC.fetch_balances([
               # start with :ok
               %{
                 block_quantity: "0x1",
                 hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
               },
               # :ok, :ok clause
               %{
                 block_quantity: "0x34",
                 hash_data: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
               },
               # :ok, :error clause
               %{
                 block_quantity: "0x2",
                 hash_data: "0x3"
               },
               # :error, :ok clause
               %{
                 block_quantity: "0x35",
                 hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
               },
               # :error, :error clause
               %{
                 block_quantity: "0x4",
                 hash_data: "0x5"
               }
             ]) ==
               {:error,
                [
                  %{
                    "blockNumber" => "0x2",
                    "code" => -32602,
                    "hash" => "0x3",
                    "message" =>
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  },
                  %{
                    "blockNumber" => "0x4",
                    "code" => -32602,
                    "hash" => "0x5",
                    "message" =>
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  }
                ]}
    end
  end

  describe "json_rpc/2" do
    @ethereum_jsonrpc_original Application.get_env(:ethereum_jsonrpc, :url)

    setup do
      bypass = Bypass.open()

      Application.put_env(:ethereum_jsonrpc, :url, "http://localhost:#{bypass.port}")

      on_exit(fn ->
        Application.put_env(:ethereum_jsonrpc, :url, @ethereum_jsonrpc_original)
      end)

      {:ok, bypass: bypass}
    end

    # regression test for https://github.com/poanetwork/poa-explorer/issues/254
    test "transparently splits batch payloads that would trigger a 413 Request Entity Too Large", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn -> Conn.resp(conn, 200, eth_get_block_by_number_response()) end)

      block_numbers = 0..13000

      payload =
        block_numbers
        |> Stream.with_index()
        |> Enum.map(&get_block_by_number_request/1)

      url = EthereumJSONRPC.config(:url)

      assert {:ok, responses} = EthereumJSONRPC.json_rpc(payload, url)

      assert Enum.count(responses) == Enum.count(block_numbers)

      block_number_set = MapSet.new(block_numbers)

      response_block_number_set =
        Enum.into(responses, MapSet.new(), fn %{"result" => %{"number" => quantity}} ->
          EthereumJSONRPC.quantity_to_integer(quantity)
        end)

      assert MapSet.equal?(response_block_number_set, block_number_set)
    end
  end

  defp get_block_by_number_request({block_number, id}) do
    %{
      "id" => id,
      "jsonrpc" => "2.0",
      "method" => "eth_getBlockByNumber",
      "params" => [EthereumJSONRPC.integer_to_quantity(block_number), true]
    }
  end

  defp eth_get_block_by_number_response() do
    File.read!("./test/support/fixture/eth_get_block_by_number.json")
  end
end
