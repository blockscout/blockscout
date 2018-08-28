defmodule Indexer.Address.TokenBalancesTest do
  use ExUnit.Case, async: true

  alias Explorer.Factory
  alias Indexer.Address.TokenBalances

  describe "params_set/1" do
    test "with token transfer extract from_address, to_address, and token_contract_address_hash" do
      block_number = 1

      from_address_hash =
        Factory.address_hash()
        |> to_string()

      to_address_hash =
        Factory.address_hash()
        |> to_string()

      token_contract_address_hash =
        Factory.address_hash()
        |> to_string()

      token_transfer_params = %{
        block_number: block_number,
        from_address_hash: from_address_hash,
        to_address_hash: to_address_hash,
        token_contract_address_hash: token_contract_address_hash
      }

      params_set = TokenBalances.params_set(%{token_transfers_params: [token_transfer_params]})

      assert MapSet.size(params_set) == 3
      assert %{address_hash: from_address_hash, block_number: block_number}
      assert %{address_hash: to_address_hash, block_number: block_number}
      assert %{address_hash: token_contract_address_hash, block_number: block_number}
    end
  end
end
