defmodule EthereumJSONRPCTest do
  use ExUnit.Case, async: true

  import EthereumJSONRPC.Case

  @moduletag :capture_log

  setup do
    %{variant: EthereumJSONRPC.config(:variant)}
  end

  describe "fetch_balances/1" do
    test "with all valid hash_data returns {:ok, addresses_params}", %{variant: variant} do
      assert {:ok,
              [
                %{
                  fetched_balance: fetched_balance,
                  fetched_balance_block_number: 1,
                  hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                }
              ]} =
               EthereumJSONRPC.fetch_balances([
                 %{block_quantity: "0x1", hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}
               ])

      case variant do
        EthereumJSONRPC.Geth ->
          assert fetched_balance == 0

        EthereumJSONRPC.Parity ->
          assert fetched_balance == 1

        _ ->
          raise ArgumentError, "Unsupported variant (#{variant}})"
      end
    end

    test "with all invalid hash_data returns {:error, reasons}", %{variant: variant} do
      assert {:error, reasons} = EthereumJSONRPC.fetch_balances([%{block_quantity: "0x1", hash_data: "0x0"}])
      assert is_list(reasons)
      assert length(reasons) == 1

      [reason] = reasons

      assert %{
               "blockNumber" => "0x1",
               "code" => -32602,
               "hash" => "0x0",
               "message" => message
             } = reason

      case variant do
        EthereumJSONRPC.Geth ->
          assert message ==
                   "invalid argument 0: json: cannot unmarshal hex string of odd length into Go value of type common.Address"

        EthereumJSONRPC.Parity ->
          assert message ==
                   "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."

        _ ->
          raise ArgumentError, "Unsupported variant (#{variant}})"
      end
    end

    test "with a mix of valid and invalid hash_data returns {:error, reasons}" do
      assert {:error, reasons} =
               EthereumJSONRPC.fetch_balances([
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
               ])

      assert is_list(reasons)
      assert length(reasons) > 1
    end
  end

  describe "fetch_block_number_by_tag/1" do
    @tag capture_log: false
    test "with earliest" do
      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("earliest") end,
        fn result ->
          assert {:ok, 0} = result
        end
      )
    end

    @tag capture_log: false
    test "with latest" do
      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("latest") end,
        fn result ->
          assert {:ok, number} = result
          assert number > 0
        end
      )
    end

    @tag capture_log: false
    test "with pending" do
      log_bad_gateway(
        fn -> EthereumJSONRPC.fetch_block_number_by_tag("pending") end,
        fn result ->
          assert {:ok, number} = result
          assert number > 0
        end
      )
    end
  end

  describe "json_rpc/2" do
    # regression test for https://github.com/poanetwork/poa-explorer/issues/254
    test "transparently splits batch payloads that would trigger a 413 Request Entity Too Large", %{variant: variant} do
      block_numbers = 0..13000

      payload =
        block_numbers
        |> Stream.with_index()
        |> Enum.map(&get_block_by_number_request/1)

      assert_payload_too_large(payload, variant)

      url = EthereumJSONRPC.config(:url)

      log_bad_gateway(
        fn -> EthereumJSONRPC.json_rpc(payload, url) end,
        fn result ->
          assert {:ok, responses} = result
          assert Enum.count(responses) == Enum.count(block_numbers)

          block_number_set = MapSet.new(block_numbers)

          response_block_number_set =
            Enum.into(responses, MapSet.new(), fn %{"result" => %{"number" => quantity}} ->
              EthereumJSONRPC.quantity_to_integer(quantity)
            end)

          assert MapSet.equal?(response_block_number_set, block_number_set)
        end
      )
    end
  end

  defp assert_payload_too_large(payload, variant) do
    json = Jason.encode_to_iodata!(payload)
    headers = [{"Content-Type", "application/json"}]
    url = EthereumJSONRPC.config(:url)

    assert {:ok, %HTTPoison.Response{body: body, status_code: 413}} =
             HTTPoison.post(url, json, headers, EthereumJSONRPC.config(:http))

    case variant do
      EthereumJSONRPC.Geth ->
        assert body =~ "content length too large"

      EthereumJSONRPC.Parity ->
        assert body =~ "413 Request Entity Too Large"

      _ ->
        raise ArgumentError, "Unsupported variant (#{variant})"
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
end
