defmodule EthereumJSONRPCTest do
  use ExUnit.Case, async: true

  import EthereumJSONRPC.Case

  @moduletag :capture_log

  setup do
    {variant, url} =
      case System.get_env("ETHEREUM_JSONRPC_VARIANT") || "parity" do
        "geth" ->
          {EthereumJSONRPC.Geth, "https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY"}

        "parity" ->
          {EthereumJSONRPC.Parity, "https://sokol-trace.poa.network"}

        variant_name ->
          raise ArgumentError, "Unsupported variant name (#{variant_name})"
      end

    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          http: EthereumJSONRPC.HTTP.HTTPoison,
          url: url,
          http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
        ],
        variant: variant
      ]
    }
  end

  describe "fetch_balances/1" do
    test "with all valid hash_data returns {:ok, addresses_params}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      assert {:ok,
              [
                %{
                  fetched_balance: fetched_balance,
                  fetched_balance_block_number: 1,
                  hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                }
              ]} =
               EthereumJSONRPC.fetch_balances(
                 [
                   %{block_quantity: "0x1", hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}
                 ],
                 json_rpc_named_arguments
               )

      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Geth ->
          assert fetched_balance == 0

        EthereumJSONRPC.Parity ->
          assert fetched_balance == 1

        variant ->
          raise ArgumentError, "Unsupported variant (#{variant}})"
      end
    end

    test "with all invalid hash_data returns {:error, reasons}", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:error, reasons} =
               EthereumJSONRPC.fetch_balances([%{block_quantity: "0x1", hash_data: "0x0"}], json_rpc_named_arguments)

      assert is_list(reasons)
      assert length(reasons) == 1

      [reason] = reasons

      assert %{
               "blockNumber" => "0x1",
               "code" => -32602,
               "hash" => "0x0",
               "message" => message
             } = reason

      case Keyword.fetch!(json_rpc_named_arguments, :variant) do
        EthereumJSONRPC.Geth ->
          assert message ==
                   "invalid argument 0: json: cannot unmarshal hex string of odd length into Go value of type common.Address"

        EthereumJSONRPC.Parity ->
          assert message ==
                   "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."

        variant ->
          raise ArgumentError, "Unsupported variant (#{variant}})"
      end
    end

    test "with a mix of valid and invalid hash_data returns {:error, reasons}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      assert {:error, reasons} =
               EthereumJSONRPC.fetch_balances(
                 [
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
                 ],
                 json_rpc_named_arguments
               )

      assert is_list(reasons)
      assert length(reasons) > 1
    end
  end

  describe "fetch_block_number_by_tag" do
    @tag capture_log: false
    test "with earliest", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("earliest", json_rpc_named_arguments) end,
        fn result ->
          assert {:ok, 0} = result
        end
      )
    end

    @tag capture_log: false
    test "with latest", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments) end,
        fn result ->
          assert {:ok, number} = result
          assert number > 0
        end
      )
    end

    @tag capture_log: false
    test "with pending", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("pending", json_rpc_named_arguments) end,
        fn result ->
          assert {:ok, number} = result
          assert number > 0
        end
      )
    end
  end
end
