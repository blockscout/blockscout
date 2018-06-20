defmodule EthereumJSONRPCTest do
  use ExUnit.Case, async: true

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
end
