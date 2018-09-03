defmodule Indexer.TokenBalancesTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  doctest Indexer.TokenBalances

  alias Indexer.TokenBalances
  alias Explorer.Chain.Hash

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "fetch_token_balances_from_blockchain/2" do
    test "fetches balances of tokens given the address hash" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      data = %{
        token_contract_address_hash: Hash.to_string(token.contract_address_hash),
        address_hash: address_hash_string,
        block_number: 1_000
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

    test "does not ignore calls that were returned with error" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      data = %{
        token_contract_address_hash: token.contract_address_hash,
        address_hash: address_hash_string,
        block_number: 1_000
      }

      get_balance_from_blockchain_with_error()

      {:ok, result} = TokenBalances.fetch_token_balances_from_blockchain([data])

      assert %{
               value: nil,
               token_contract_address_hash: token_contract_address_hash,
               address_hash: address_hash,
               block_number: 1_000,
               value_fetched_at: nil
             } = List.first(result)
    end

    test "ignores results that raised :timeout" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      token_balance_params = [
        %{
          token_contract_address_hash: Hash.to_string(token.contract_address_hash),
          address_hash: address_hash_string,
          block_number: 1_000
        },
        %{
          token_contract_address_hash: Hash.to_string(token.contract_address_hash),
          address_hash: address_hash_string,
          block_number: 1_001
        }
      ]

      get_balance_from_blockchain()
      get_balance_from_blockchain_with_timeout()

      {:ok, result} = TokenBalances.fetch_token_balances_from_blockchain(token_balance_params)

      assert length(result) == 1
    end
  end

  defp get_balance_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: _, method: _, params: [%{data: _, to: _}, _]}], _options ->
        {:ok,
         [
           %{
             id: "balanceOf",
             jsonrpc: "2.0",
             result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
           }
         ]}
      end
    )
  end

  defp get_balance_from_blockchain_with_timeout() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: _, method: _, params: [%{data: _, to: _}, _]}], _options ->
        :timer.sleep(5001)
      end
    )
  end

  defp get_balance_from_blockchain_with_error() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: _, method: _, params: [%{data: _, to: _}, _]}], _options ->
        {:ok,
         [
           %{
             error: %{code: -32015, data: "Reverted 0x", message: "VM execution error."},
             id: "balanceOf",
             jsonrpc: "2.0"
           }
         ]}
      end
    )
  end
end
