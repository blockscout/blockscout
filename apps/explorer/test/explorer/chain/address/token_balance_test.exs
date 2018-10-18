defmodule Explorer.Chain.Address.TokenBalanceTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Token
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

  describe "tokens_grouped_by_number_of_holders/0" do
    test "groups all tokens with their number of holders" do
      token_a = insert(:token)
      address_a = insert(:address, hash: "0xc45e4830dff873cf8b70de2b194d0ddd06ef651d")

      insert(:token_balance, address: address_a, value: 10, token_contract_address_hash: token_a.contract_address_hash)

      token_b = insert(:token)
      address_b = insert(:address, hash: "0xc45e4830dff873cf8b70de2b194d0ddd06ef651e")
      address_c = insert(:address, hash: "0xc45e4830dff873cf8b70de2b194d0ddd06ef651f")

      insert(
        :token_balance,
        address: address_b,
        value: 10,
        token_contract_address_hash: token_b.contract_address_hash
      )

      insert(
        :token_balance,
        address: address_c,
        value: 10,
        token_contract_address_hash: token_b.contract_address_hash
      )

      result =
        TokenBalance.tokens_grouped_by_number_of_holders()
        |> Repo.all()
        |> Enum.sort(fn {_token_hash_a, holders_a}, {_token_hash_b, holders_b} ->
          holders_a < holders_b
        end)

      assert [{token_a_result, 1}, {token_b_result, 2}] = result
      assert token_a_result == token_a.contract_address_hash
      assert token_b_result == token_b.contract_address_hash
    end

    test "considers only the last block" do
      address = insert(:address, hash: "0xe49fedd93960a0267b3c3b2c1e2d66028e013fee")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :token_balance,
        address: address,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 1000
      )

      [{_, result}] = Repo.all(TokenBalance.tokens_grouped_by_number_of_holders())

      assert result == 1
    end

    test "counts only the last block that has value greater than 0" do
      address = insert(:address, hash: "0xe49fedd93960a0267b3c3b2c1e2d66028e013fee")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :token_balance,
        address: address,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 0
      )

      result =
        TokenBalance.tokens_grouped_by_number_of_holders()
        |> Repo.all()
        |> Enum.count()

      assert result == 0
    end

    test "does not consider the burn address" do
      burn_address = insert(:address, hash: "0x0000000000000000000000000000000000000000")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: burn_address,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      result =
        TokenBalance.tokens_grouped_by_number_of_holders()
        |> Repo.all()
        |> Enum.count()

      assert result == 0
    end

    test "considers the same address for different tokens" do
      address = insert(:address, hash: "0xe49fedd93960a0267b3c3b2c1e2d66028e013fee")

      %Token{contract_address_hash: contract_address_hash_1} = insert(:token)
      %Token{contract_address_hash: contract_address_hash_2} = insert(:token)

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash_1,
        value: 5000
      )

      insert(
        :token_balance,
        address: address,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash_2,
        value: 5000
      )

      result =
        TokenBalance.tokens_grouped_by_number_of_holders()
        |> Repo.all()
        |> Enum.count()

      assert result == 2
    end
  end
end
