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

      assert MapSet.size(params_set) == 2
      assert %{address_hash: from_address_hash, block_number: block_number}
      assert %{address_hash: to_address_hash, block_number: block_number}
      assert %{address_hash: token_contract_address_hash, block_number: block_number}
    end

    test "does set params when the from_address_hash is the burn address for the Token ERC-721" do
      block_number = 1
      from_address_hash = "0x0000000000000000000000000000000000000000"
      to_address_hash = "0x5b8410f67eb8040bb1cd1e8a4ff9d5f6ce678a15"
      token_contract_address_hash = "0xe18035bf8712672935fdb4e5e431b1a0183d2dfc"

      token_transfer_params = %{
        block_number: block_number,
        from_address_hash: from_address_hash,
        to_address_hash: to_address_hash,
        token_contract_address_hash: token_contract_address_hash,
        token_type: "ERC-721"
      }

      params_set = TokenBalances.params_set(%{token_transfers_params: [token_transfer_params]})

      assert params_set ==
               MapSet.new([
                 %{
                   address_hash: "0x0000000000000000000000000000000000000000",
                   block_number: 1,
                   token_contract_address_hash: "0xe18035bf8712672935fdb4e5e431b1a0183d2dfc"
                 },
                 %{
                   address_hash: "0x5b8410f67eb8040bb1cd1e8a4ff9d5f6ce678a15",
                   block_number: 1,
                   token_contract_address_hash: "0xe18035bf8712672935fdb4e5e431b1a0183d2dfc"
                 }
               ])
    end

    test "does not set params when the to_address_hash is the burn address for the Token ERC-721" do
      block_number = 1
      from_address_hash = "0x5b8410f67eb8040bb1cd1e8a4ff9d5f6ce678a15"
      to_address_hash = "0x0000000000000000000000000000000000000000"
      token_contract_address_hash = "0xe18035bf8712672935fdb4e5e431b1a0183d2dfc"

      token_transfer_params = %{
        block_number: block_number,
        from_address_hash: from_address_hash,
        to_address_hash: to_address_hash,
        token_contract_address_hash: token_contract_address_hash,
        token_type: "ERC-721"
      }

      params_set = TokenBalances.params_set(%{token_transfers_params: [token_transfer_params]})

      assert MapSet.size(params_set) == 0
    end
  end
end
