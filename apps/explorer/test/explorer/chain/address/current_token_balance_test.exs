defmodule Explorer.Chain.Address.CurrentTokenBalanceTest do
  use Explorer.DataCase

  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.Token
  alias Explorer.Chain.Address.CurrentTokenBalance

  describe "token_holders_ordered_by_value/2" do
    test "returns the last value for each address" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token)
      address_a = insert(:address)
      address_b = insert(:address)

      insert(
        :address_current_token_balance,
        address: address_a,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :address_current_token_balance,
        address: address_b,
        block_number: 1001,
        token_contract_address_hash: contract_address_hash,
        value: 4000
      )

      token_holders_count =
        contract_address_hash
        |> CurrentTokenBalance.token_holders_ordered_by_value()
        |> Repo.all()
        |> Enum.count()

      assert token_holders_count == 2
    end

    test "sort by the highest value" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token)
      address_a = insert(:address)
      address_b = insert(:address)
      address_c = insert(:address)

      insert(
        :address_current_token_balance,
        address: address_a,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :address_current_token_balance,
        address: address_b,
        token_contract_address_hash: contract_address_hash,
        value: 4000
      )

      insert(
        :address_current_token_balance,
        address: address_c,
        token_contract_address_hash: contract_address_hash,
        value: 15000
      )

      token_holders_values =
        contract_address_hash
        |> CurrentTokenBalance.token_holders_ordered_by_value()
        |> Repo.all()
        |> Enum.map(&Decimal.to_integer(&1.value))

      assert token_holders_values == [15_000, 5_000, 4_000]
    end

    test "returns only token balances that have value greater than 0" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :address_current_token_balance,
        token_contract_address_hash: contract_address_hash,
        value: 0
      )

      result =
        contract_address_hash
        |> CurrentTokenBalance.token_holders_ordered_by_value()
        |> Repo.all()

      assert result == []
    end

    test "ignores the burn address" do
      {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")

      burn_address = insert(:address, hash: burn_address_hash)

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :address_current_token_balance,
        address: burn_address,
        token_contract_address_hash: contract_address_hash,
        value: 1000
      )

      result =
        contract_address_hash
        |> CurrentTokenBalance.token_holders_ordered_by_value()
        |> Repo.all()

      assert result == []
    end

    test "paginates the result by value and different address" do
      address_a = build(:address, hash: "0xcb2cf1fd3199584ac5faa16c6aca49472dc6495a")
      address_b = build(:address, hash: "0x5f26097334b6a32b7951df61fd0c5803ec5d8354")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      first_page =
        insert(
          :address_current_token_balance,
          address: address_a,
          token_contract_address_hash: contract_address_hash,
          value: 4000
        )

      second_page =
        insert(
          :address_current_token_balance,
          address: address_b,
          token_contract_address_hash: contract_address_hash,
          value: 4000
        )

      paging_options = %PagingOptions{
        key: {first_page.value, first_page.address_hash},
        page_size: 2
      }

      result_paginated =
        contract_address_hash
        |> CurrentTokenBalance.token_holders_ordered_by_value(paging_options: paging_options)
        |> Repo.all()
        |> Enum.map(& &1.address_hash)

      assert result_paginated == [second_page.address_hash]
    end
  end

  describe "last_token_balances/1" do
    test "returns the current token balances of the given address" do
      address = insert(:address)
      current_token_balance = insert(:address_current_token_balance, address: address)
      insert(:address_current_token_balance, address: build(:address))

      token_balances =
        address.hash
        |> CurrentTokenBalance.last_token_balances()
        |> Repo.all()
        |> Enum.map(fn {token_balance, _} -> token_balance.address_hash end)

      assert token_balances == [current_token_balance.address_hash]
    end

    test "returns an empty list when there are no token balances" do
      address = insert(:address)

      insert(:address_current_token_balance, address: build(:address))

      token_balances =
        address.hash
        |> CurrentTokenBalance.last_token_balances()
        |> Repo.all()

      assert token_balances == []
    end

    test "does not consider tokens that have value 0" do
      address = insert(:address)

      current_token_balance_a =
        insert(
          :address_current_token_balance,
          address: address,
          value: 5000
        )

      insert(
        :address_current_token_balance,
        address: address,
        value: 0
      )

      token_balances =
        address.hash
        |> CurrentTokenBalance.last_token_balances()
        |> Repo.all()
        |> Enum.map(fn {token_balance, _} -> token_balance.address_hash end)

      assert token_balances == [current_token_balance_a.address_hash]
    end
  end
end
