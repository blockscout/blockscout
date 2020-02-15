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

      data = %{
        token_contract_address_hash: Hash.to_string(token.contract_address_hash),
        address_hash: address_hash_string,
        block_number: 1_000,
        token_id: 11,
        token_type: "ERC-20"
      }

      get_balance_from_blockchain()

      {:ok, result} = TokenBalances.fetch_token_balances_from_blockchain([data])

      assert %{
               value: 1_000_000_000_000_000_000_000_000,
               token_contract_address_hash: token_contract_address_hash,
               address_hash: address_hash,
               block_number: 1_000,
               value_fetched_at: _
             } = List.first(result)
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
        address_hash: address_hash_string,
        block_number: 1_000
      }

      token_balance_b = %{
        token_contract_address_hash: Hash.to_string(token.contract_address_hash),
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
