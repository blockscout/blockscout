defmodule Explorer.Chain.Address.TokenBalanceTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Address.TokenBalance

  describe "unfetched_token_balances/0" do
    test "returns only the token balances that have value_fetched_at nil" do
      address = insert(:address, hash: "0xc45e4830dff873cf8b70de2b194d0ddd06ef651e")
      token_balance = insert(:token_balance, value_fetched_at: nil, address: address)
      insert(:token_balance)

      result =
        TokenBalance.unfetched_token_balances()
        |> Repo.all()
        |> List.first()

      assert result.block_number == token_balance.block_number
    end

    test "does not ignore token balance when the address isn't the burn address with Token ERC-20" do
      address = insert(:address, hash: "0xc45e4830dff873cf8b70de2b194d0ddd06ef651e")
      token = insert(:token, type: "ERC-20")

      token_balance =
        insert(
          :token_balance,
          value_fetched_at: nil,
          address: address,
          token_contract_address_hash: token.contract_address_hash
        )

      result =
        TokenBalance.unfetched_token_balances()
        |> Repo.all()
        |> List.first()

      assert result.block_number == token_balance.block_number
    end

    test "ignores the burn_address when the token type is ERC-721" do
      burn_address = insert(:address, hash: "0x0000000000000000000000000000000000000000")
      token = insert(:token, type: "ERC-721")

      insert(
        :token_balance,
        address: burn_address,
        token_contract_address_hash: token.contract_address_hash,
        value_fetched_at: nil
      )

      result =
        TokenBalance.unfetched_token_balances()
        |> Repo.all()

      assert result == []
    end

    test "does not ignore the burn_address when the token type is ERC-20" do
      burn_address = insert(:address, hash: "0x0000000000000000000000000000000000000000")
      token = insert(:token, type: "ERC-20")

      token_balance =
        insert(
          :token_balance,
          address: burn_address,
          token_contract_address_hash: token.contract_address_hash,
          value_fetched_at: nil
        )

      result =
        TokenBalance.unfetched_token_balances()
        |> Repo.all()
        |> List.first()

      assert result.block_number == token_balance.block_number
    end
  end
end
