defmodule Explorer.Token.BalanceReaderTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  doctest Explorer.Token.BalanceReader

  alias Explorer.Token.{BalanceReader}
  alias Explorer.Chain.Hash

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

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

      result =
        BalanceReader.get_balances_of([
          %{
            token_contract_address_hash: token_contract_address_hash,
            address_hash: address_hash,
            block_number: block_number,
            token_type: "ERC-20"
          }
        ])

      assert result == [{:ok, 1_000_000_000_000_000_000_000_000}]
    end

    test "returns the error message when there is one", %{address: address, token: token} do
      block_number = 1_000
      token_contract_address_hash = Hash.to_string(token.contract_address_hash)
      address_hash = Hash.to_string(address.hash)

      get_balance_from_blockchain_with_error()

      result =
        BalanceReader.get_balances_of([
          %{
            token_contract_address_hash: token_contract_address_hash,
            address_hash: address_hash,
            block_number: block_number,
            token_type: "ERC-20"
          }
        ])

      assert result == [{:error, "(-32015) VM execution error. (Reverted 0x)"}]
    end
  end

  defp get_balance_from_blockchain() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_call", params: _}], _options ->
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
      fn [%{id: id, method: "eth_call", params: _}], _options ->
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
