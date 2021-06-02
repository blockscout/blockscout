defmodule Indexer.TokenBalancesTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  doctest Indexer.TokenBalances

  alias Indexer.TokenBalances
  alias Indexer.Fetcher.TokenBalance
  alias Explorer.Chain.Hash

  import Mox
  import ExUnit.CaptureLog

  setup :verify_on_exit!
  setup :set_mox_global

  describe "fetch_token_balances_from_blockchain/2" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "fetches balances of tokens given the address hash" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      token_contract_address_hash = Hash.to_string(token.contract_address_hash)

      data = %{
        token_contract_address_hash: token_contract_address_hash,
        address_hash: address_hash_string,
        block_number: 1_000,
        token_id: 11,
        token_type: "ERC-20"
      }

      get_balance_from_blockchain()

      {:ok, result} = TokenBalances.fetch_token_balances_from_blockchain([data])

      assert %{
               value: 1_000_000_000_000_000_000_000_000,
               token_contract_address_hash: ^token_contract_address_hash,
               address_hash: ^address_hash_string,
               block_number: 1_000,
               value_fetched_at: _
             } = List.first(result)
    end

    test "fetches balances of ERC-1155 tokens" do
      address = insert(:address, hash: "0x609991ca0ae39bc4eaf2669976237296d40c2f31")

      address_hash_string = Hash.to_string(address.hash)

      token_contract_address_hash = "0xf7f79032fd395978acb7069c74d21e5a53206559"

      contract_address = insert(:address, hash: token_contract_address_hash)

      token = insert(:token, contract_address: contract_address)

      data = [
        %{
          token_contract_address_hash: Hash.to_string(token.contract_address_hash),
          address_hash: address_hash_string,
          block_number: 1_000,
          token_id: 5,
          token_type: "ERC-1155"
        }
      ]

      get_erc1155_balance_from_blockchain()

      {:ok, result} = TokenBalances.fetch_token_balances_from_blockchain(data)

      assert [
               %{
                 value: 2,
                 token_contract_address_hash: ^token_contract_address_hash,
                 address_hash: ^address_hash_string,
                 block_number: 1_000,
                 value_fetched_at: _
               }
             ] = result
    end

    test "fetches multiple balances of tokens" do
      address_1 = insert(:address, hash: "0xecba3c9ea993b0e0594e0b0a0d361a1f9596e310")
      address_2 = insert(:address, hash: "0x609991ca0ae39bc4eaf2669976237296d40c2f31")
      address_3 = insert(:address, hash: "0xf712a82dd8e2ac923299193e9d6daeda2d5a32fd")

      address_1_hash_string = Hash.to_string(address_1.hash)
      address_2_hash_string = Hash.to_string(address_2.hash)
      address_3_hash_string = Hash.to_string(address_3.hash)

      token_1_contract_address_hash = "0x57e93bb58268de818b42e3795c97bad58afcd3fe"
      token_2_contract_address_hash = "0xe0d0b1dbbcf3dd5cac67edaf9243863fd70745da"
      token_3_contract_address_hash = "0x22c1f6050e56d2876009903609a2cc3fef83b415"
      token_4_contract_address_hash = "0xf7f79032fd395978acb7069c74d21e5a53206559"

      contract_address_1 = insert(:address, hash: token_1_contract_address_hash)
      contract_address_2 = insert(:address, hash: token_2_contract_address_hash)
      contract_address_3 = insert(:address, hash: token_3_contract_address_hash)
      contract_address_4 = insert(:address, hash: token_4_contract_address_hash)

      token_1 = insert(:token, contract_address: contract_address_1)
      token_2 = insert(:token, contract_address: contract_address_2)
      token_3 = insert(:token, contract_address: contract_address_3)
      token_4 = insert(:token, contract_address: contract_address_4)

      data = [
        %{
          token_contract_address_hash: Hash.to_string(token_1.contract_address_hash),
          address_hash: address_1_hash_string,
          block_number: 1_000,
          token_id: nil,
          token_type: "ERC-20"
        },
        %{
          token_contract_address_hash: Hash.to_string(token_2.contract_address_hash),
          address_hash: address_2_hash_string,
          block_number: 1_000,
          token_id: nil,
          token_type: "ERC-20"
        },
        %{
          token_contract_address_hash: Hash.to_string(token_3.contract_address_hash),
          address_hash: address_2_hash_string,
          block_number: 1_000,
          token_id: 42,
          token_type: "ERC-721"
        },
        %{
          token_contract_address_hash: Hash.to_string(token_4.contract_address_hash),
          address_hash: address_2_hash_string,
          block_number: 1_000,
          token_id: 5,
          token_type: "ERC-1155"
        },
        %{
          token_contract_address_hash: Hash.to_string(token_2.contract_address_hash),
          address_hash: Hash.to_string(token_2.contract_address_hash),
          block_number: 1_000,
          token_id: nil,
          token_type: "ERC-20"
        },
        %{
          token_contract_address_hash: Hash.to_string(token_2.contract_address_hash),
          address_hash: address_3_hash_string,
          block_number: 1_000,
          token_id: nil,
          token_type: "ERC-20"
        },
        %{
          token_contract_address_hash: Hash.to_string(token_2.contract_address_hash),
          address_hash: Hash.to_string(token_2.contract_address_hash),
          block_number: 1_000,
          token_id: nil,
          token_type: "ERC-20"
        }
      ]

      get_multiple_balances_from_blockchain()
      get_erc1155_balance_from_blockchain()

      {:ok, result} = TokenBalances.fetch_token_balances_from_blockchain(data)

      assert [
               %{
                 value: 1_000_000_000_000_000_000_000_000,
                 token_contract_address_hash: ^token_1_contract_address_hash,
                 address_hash: ^address_1_hash_string,
                 block_number: 1_000,
                 value_fetched_at: _
               },
               %{
                 value: 3_000_000_000_000_000_000_000_000_000,
                 token_contract_address_hash: ^token_2_contract_address_hash,
                 address_hash: ^address_2_hash_string,
                 block_number: 1_000,
                 value_fetched_at: _
               },
               %{
                 value: 1,
                 token_contract_address_hash: ^token_3_contract_address_hash,
                 address_hash: ^address_2_hash_string,
                 block_number: 1_000,
                 value_fetched_at: _
               },
               %{
                 value: 6_000_000_000_000_000_000_000_000_000,
                 token_contract_address_hash: ^token_2_contract_address_hash,
                 address_hash: ^token_2_contract_address_hash,
                 block_number: 1_000,
                 value_fetched_at: _
               },
               %{
                 value: 5_000_000_000_000_000_000_000_000_000,
                 token_contract_address_hash: ^token_2_contract_address_hash,
                 address_hash: ^address_3_hash_string,
                 block_number: 1_000,
                 value_fetched_at: _
               },
               %{
                 value: 6_000_000_000_000_000_000_000_000_000,
                 token_contract_address_hash: ^token_2_contract_address_hash,
                 address_hash: ^token_2_contract_address_hash,
                 block_number: 1_000,
                 value_fetched_at: _
               },
               %{
                 value: 2,
                 token_contract_address_hash: ^token_4_contract_address_hash,
                 address_hash: ^address_2_hash_string,
                 block_number: 1_000,
                 value_fetched_at: _
               }
             ] = result
    end

    test "ignores calls that gave errors to try fetch they again later" do
      address = insert(:address, hash: "0x7113ffcb9c18a97da1b9cfc43e6cb44ed9165509")
      token = insert(:token, contract_address: build(:contract_address))

      token_balances = [
        %{
          address_hash: to_string(address.hash),
          block_number: 1_000,
          token_contract_address_hash: to_string(token.contract_address_hash),
          retries_count: 1,
          token_id: 11,
          token_type: "ERC-20"
        }
      ]

      get_balance_from_blockchain_with_error()

      assert TokenBalances.fetch_token_balances_from_blockchain(token_balances) == {:ok, []}
    end
  end

  describe "log_fetching_errors" do
    test "logs the given from argument in final message" do
      token_balance_params_with_error = Map.put(build(:token_balance), :error, "Error")
      params = [token_balance_params_with_error]

      log_message_response =
        capture_log(fn ->
          TokenBalances.log_fetching_errors(params)
        end)

      assert log_message_response =~ "Error"
    end

    test "log when there is a token_balance param with errors" do
      token_balance_params_with_error = Map.merge(build(:token_balance), %{error: "Error", retries_count: 1})
      params = [token_balance_params_with_error]

      log_message_response =
        capture_log(fn ->
          TokenBalances.log_fetching_errors(params)
        end)

      assert log_message_response =~ "Error"
    end

    test "log multiple token balances params with errors" do
      error_1 = "Error"
      error_2 = "BadGateway"

      params = [
        Map.put(build(:token_balance), :error, error_1),
        Map.put(build(:token_balance), :error, error_2)
      ]

      log_message_response =
        capture_log(fn ->
          TokenBalances.log_fetching_errors(params)
        end)

      assert log_message_response =~ error_1
      assert log_message_response =~ error_2
    end

    test "doesn't log when there aren't errors after fetching token balances" do
      token_balance_params = Map.put(build(:token_balance), :error, nil)
      params = [token_balance_params]

      log_message_response =
        capture_log(fn ->
          TokenBalances.log_fetching_errors(params)
        end)

      assert log_message_response == ""
    end
  end

  describe "unfetched_token_balances/2" do
    test "finds unfetched token balances given all token balances" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      token_balance_a = %{
        token_contract_address_hash: Hash.to_string(token.contract_address_hash),
        token_id: nil,
        address_hash: address_hash_string,
        block_number: 1_000
      }

      token_balance_b = %{
        token_contract_address_hash: Hash.to_string(token.contract_address_hash),
        token_id: nil,
        address_hash: address_hash_string,
        block_number: 1_001
      }

      token_balances = MapSet.new([token_balance_a, token_balance_b])
      fetched_token_balances = MapSet.new([token_balance_a])

      assert TokenBalances.unfetched_token_balances(token_balances, fetched_token_balances) == [token_balance_b]
    end
  end

  defp get_balance_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_call", params: [%{data: _, to: _}, _]}], _options ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
           }
         ]}
      end
    )
  end

  defp get_erc1155_balance_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn requests, _options ->
        {:ok,
         requests
         |> Enum.map(fn
           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data:
                   "0x00fdd58e000000000000000000000000609991ca0ae39bc4eaf2669976237296d40c2f310000000000000000000000000000000000000000000000000000000000000005",
                 to: "0xf7f79032fd395978acb7069c74d21e5a53206559"
               },
               _
             ]
           } ->
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000002"
             }

           req ->
             IO.inspect("Gimme req")
             IO.inspect(req)
         end)
         |> Enum.shuffle()}
      end
    )
  end

  defp get_multiple_balances_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn requests, _options ->
        {:ok,
         requests
         |> Enum.map(fn
           %{id: id, method: "eth_call", params: [%{data: _, to: "0x57e93bb58268de818b42e3795c97bad58afcd3fe"}, _]} ->
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
             }

           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x70a08231000000000000000000000000609991ca0ae39bc4eaf2669976237296d40c2f31",
                 to: "0xe0d0b1dbbcf3dd5cac67edaf9243863fd70745da"
               },
               _
             ]
           } ->
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x000000000000000000000000000000000000000009b18ab5df7180b6b8000000"
             }

           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x70a08231000000000000000000000000609991ca0ae39bc4eaf2669976237296d40c2f31",
                 to: "0x22c1f6050e56d2876009903609a2cc3fef83b415"
               },
               _
             ]
           } ->
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }

           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x70a08231000000000000000000000000f712a82dd8e2ac923299193e9d6daeda2d5a32fd",
                 to: "0xe0d0b1dbbcf3dd5cac67edaf9243863fd70745da"
               },
               _
             ]
           } ->
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000001027e72f1f12813088000000"
             }

           %{
             id: id,
             method: "eth_call",
             params: [
               %{
                 data: "0x70a08231000000000000000000000000e0d0b1dbbcf3dd5cac67edaf9243863fd70745da",
                 to: "0xe0d0b1dbbcf3dd5cac67edaf9243863fd70745da"
               },
               _
             ]
           } ->
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000001363156bbee3016d70000000"
             }
         end)
         |> Enum.shuffle()}
      end
    )
  end

  defp get_balance_from_blockchain_with_error() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_call", params: [%{data: _, to: _}, _]}], _options ->
        {:ok,
         [
           %{
             error: %{code: -32015, data: "Reverted 0x", message: "VM execution error."},
             id: id,
             jsonrpc: "2.0"
           }
         ]}
      end
    )
  end
end
