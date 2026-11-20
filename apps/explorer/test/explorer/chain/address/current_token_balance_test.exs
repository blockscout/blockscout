# SPDX-License-Identifier: LicenseRef-Blockscout
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
        |> Enum.map(fn token_balance -> token_balance.address_hash end)

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
        |> Enum.map(fn token_balance -> token_balance.address_hash end)

      assert token_balances == [current_token_balance_a.address_hash]
    end

    test "prices an ERC-8056 balance by its displayed amount, not its raw one" do
      address = insert(:address)

      # `fiat_value` quotes the UI amount, which is twice the raw one here
      token =
        insert(:token,
          type: "ERC-8056",
          decimals: 0,
          fiat_value: Decimal.new(3),
          ui_multiplier: Decimal.new("2000000000000000000")
        )

      insert(:address_current_token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 5
      )

      assert [%{fiat_value: fiat_value}] =
               address.hash |> CurrentTokenBalance.last_token_balances() |> Repo.all()

      assert Decimal.equal?(fiat_value, Decimal.new(30))
    end

    test "takes the maturing of a scheduled multiplier change into account when pricing" do
      address = insert(:address)

      token =
        insert(:token,
          type: "ERC-8056",
          decimals: 0,
          fiat_value: Decimal.new(3),
          ui_multiplier: Decimal.new("1000000000000000000"),
          new_ui_multiplier: Decimal.new("2000000000000000000"),
          ui_multiplier_effective_at: DateTime.add(DateTime.utc_now(), -1, :hour)
        )

      insert(:address_current_token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 5
      )

      assert [%{fiat_value: fiat_value}] =
               address.hash |> CurrentTokenBalance.last_token_balances() |> Repo.all()

      assert Decimal.equal?(fiat_value, Decimal.new(30))
    end

    test "leaves a token without ERC-8056 support priced by its raw balance" do
      address = insert(:address)
      token = insert(:token, decimals: 0, fiat_value: Decimal.new(3))

      insert(:address_current_token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 5
      )

      assert [%{fiat_value: fiat_value}] =
               address.hash |> CurrentTokenBalance.last_token_balances() |> Repo.all()

      assert Decimal.equal?(fiat_value, Decimal.new(15))
    end
  end

  describe "count_token_holders_from_token_hash" do
    test "returns the most current count about token holders" do
      address_a = insert(:address, hash: "0xe49fedd93960a0267b3c3b2c1e2d66028e013fee")
      address_b = insert(:address, hash: "0x5f26097334b6a32b7951df61fd0c5803ec5d8354")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :address_current_token_balance,
        address: address_a,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :address_current_token_balance,
        address: address_b,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 1000
      )

      assert CurrentTokenBalance.count_token_holders_from_token_hash(contract_address_hash) == 2
    end
  end

  describe "record_backfill_failures/1" do
    setup do
      %{
        token: insert(:token, type: "ERC-20"),
        zero_address: insert(:address, hash: "0x0000000000000000000000000000000000000000")
      }
    end

    defp failure(token, address, retries_count, refetch_after) do
      %{
        address_hash: to_string(address.hash),
        token_contract_address_hash: to_string(token.contract_address_hash),
        token_type: "ERC-20",
        block_number: 20,
        retries_count: retries_count,
        refetch_after: refetch_after
      }
    end

    defp zero_address_ctb(token) do
      Repo.get_by!(CurrentTokenBalance,
        address_hash: "0x0000000000000000000000000000000000000000",
        token_contract_address_hash: token.contract_address_hash
      )
    end

    test "inserts a missing balance as unfetched with its retry state", %{token: token, zero_address: zero_address} do
      refetch_after = ~U[2030-01-01 00:00:00.000000Z]

      assert CurrentTokenBalance.record_backfill_failures([failure(token, zero_address, 1, refetch_after)]) == 1

      ctb = zero_address_ctb(token)
      assert is_nil(ctb.value)
      assert is_nil(ctb.value_fetched_at)
      assert ctb.block_number == 20
      assert ctb.retries_count == 1
      assert Timex.equal?(ctb.refetch_after, refetch_after)
    end

    test "leaves a fetched balance unchanged", %{token: token, zero_address: zero_address} do
      fetched_at = ~U[2026-01-01 00:00:00.000000Z]

      insert(:address_current_token_balance,
        address: zero_address,
        token_contract_address_hash: token.contract_address_hash,
        token_type: "ERC-20",
        block_number: 10,
        value: 5,
        value_fetched_at: fetched_at,
        retries_count: nil,
        refetch_after: nil
      )

      assert CurrentTokenBalance.record_backfill_failures([
               failure(token, zero_address, 1, ~U[2030-01-01 00:00:00.000000Z])
             ]) == 0

      ctb = zero_address_ctb(token)
      assert Decimal.eq?(ctb.value, 5)
      assert Timex.equal?(ctb.value_fetched_at, fetched_at)
      assert ctb.block_number == 10
      assert is_nil(ctb.retries_count)
    end

    test "advances the retry state of a never fetched balance and never moves it back", %{
      token: token,
      zero_address: zero_address
    } do
      insert(:address_current_token_balance,
        address: zero_address,
        token_contract_address_hash: token.contract_address_hash,
        token_type: "ERC-20",
        block_number: 10,
        value: nil,
        value_fetched_at: nil,
        retries_count: 2,
        refetch_after: ~U[2030-01-01 00:00:00.000000Z]
      )

      # lower count, then same count with an earlier deadline: ignored
      assert CurrentTokenBalance.record_backfill_failures([
               failure(token, zero_address, 1, ~U[2031-01-01 00:00:00.000000Z])
             ]) == 0

      assert CurrentTokenBalance.record_backfill_failures([
               failure(token, zero_address, 2, ~U[2029-01-01 00:00:00.000000Z])
             ]) == 0

      # higher count: recorded, block kept
      assert CurrentTokenBalance.record_backfill_failures([
               failure(token, zero_address, 3, ~U[2031-01-01 00:00:00.000000Z])
             ]) == 1

      ctb = zero_address_ctb(token)
      assert ctb.retries_count == 3
      assert Timex.equal?(ctb.refetch_after, ~U[2031-01-01 00:00:00.000000Z])
      assert ctb.block_number == 10
    end
  end
end
