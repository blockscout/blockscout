defmodule Explorer.Token.BalanceReaderTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  doctest Explorer.Token.BalanceReader

  alias Explorer.Token.{BalanceReader}
  alias Explorer.Chain.Hash

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "fetch_token_balances_from_blockchain/2" do
    test "fetches balances of tokens given the address hash" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      get_balance_from_blockchain()

      result =
        [token]
        |> BalanceReader.fetch_token_balances_from_blockchain(address_hash_string)
        |> List.first()

      assert result == {:ok, Map.put(token, :balance, 1_000_000_000_000_000_000_000_000)}
    end

    test "does not ignore calls that were returned with error" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      get_balance_from_blockchain_with_error()

      result =
        [token]
        |> BalanceReader.fetch_token_balances_from_blockchain(address_hash_string)
        |> List.first()

      assert result == {:error, Map.put(token, :balance, "(-32015) VM execution error.")}
    end
  end

  describe "fetch_token_balances_without_error/2" do
    test "filters token balances that were fetched without error" do
      address = insert(:address)
      token_a = insert(:token, contract_address: build(:contract_address))
      token_b = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      get_balance_from_blockchain()
      get_balance_from_blockchain_with_error()

      results =
        [token_a, token_b]
        |> BalanceReader.fetch_token_balances_without_error(address_hash_string)

      assert Enum.count(results) == 1
      assert List.first(results) == Map.put(token_a, :balance, 1_000_000_000_000_000_000_000_000)
    end

    test "does not considers balances equal 0" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))
      address_hash_string = Hash.to_string(address.hash)

      get_balance_from_blockchain_with_balance_zero()

      results =
        [token]
        |> BalanceReader.fetch_token_balances_without_error(address_hash_string)

      assert Enum.count(results) == 0
    end
  end

  describe "get_balance_of/3" do
    setup do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))

      %{address: address, token: token}
    end

    test "returns the token's balance that the given address has", %{address: address, token: token} do
      block_number = 1_000
      token_contract_address_hash = Hash.to_string(token.contract_address_hash)
      address_hash = Hash.to_string(address.hash)

      get_balance_from_blockchain()

      result = BalanceReader.get_balance_of(token_contract_address_hash, address_hash, block_number)

      assert result == {:ok, 1_000_000_000_000_000_000_000_000}
    end

    test "returns the error message when there is one", %{address: address, token: token} do
      block_number = 1_000
      token_contract_address_hash = Hash.to_string(token.contract_address_hash)
      address_hash = Hash.to_string(address.hash)

      get_balance_from_blockchain_with_error()

      result = BalanceReader.get_balance_of(token_contract_address_hash, address_hash, block_number)

      assert result == {:error, "(-32015) VM execution error."}
    end
  end

  defp get_balance_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: _, method: _, params: _}], _options ->
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

  defp get_balance_from_blockchain_with_balance_zero() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: _, method: _, params: [%{data: _, to: _}]}], _options ->
        {:ok,
         [
           %{
             id: "balanceOf",
             jsonrpc: "2.0",
             result: "0x0000000000000000000000000000000000000000000000000000000000000000"
           }
         ]}
      end
    )
  end

  defp get_balance_from_blockchain_with_error() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: _, method: _, params: _}], _options ->
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
