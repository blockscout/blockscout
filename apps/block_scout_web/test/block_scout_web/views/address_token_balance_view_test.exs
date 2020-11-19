defmodule BlockScoutWeb.AddressTokenBalanceViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressTokenBalanceView

  describe "tokens_count_title/1" do
    test "returns the title pluralized" do
      token_balances = [
        build(:token_balance),
        build(:token_balance)
      ]

      assert AddressTokenBalanceView.tokens_count_title(token_balances) == "2 tokens"
    end
  end

  describe "filter_by_type/2" do
    test "filter tokens by the given type" do
      token_balance_a = build(:token_balance, token: build(:token, type: "ERC-20"))
      token_balance_b = build(:token_balance, token: build(:token, type: "ERC-721"))

      token_balances = [token_balance_a, token_balance_b]

      assert AddressTokenBalanceView.filter_by_type(token_balances, "ERC-20") == [token_balance_a]
    end
  end

  describe "sort_by_name/1" do
    test "sorts the given tokens by its name" do
      token_balance_a = build(:token_balance, token: build(:token, name: "token name"))
      token_balance_b = build(:token_balance, token: build(:token, name: "token"))
      token_balance_c = build(:token_balance, token: build(:token, name: "atoken"))

      token_balances = [
        token_balance_a,
        token_balance_b,
        token_balance_c
      ]

      expected = [token_balance_c, token_balance_b, token_balance_a]

      assert AddressTokenBalanceView.sort_by_name(token_balances) == expected
    end

    test "considers nil values in the bottom of the list" do
      token_balance_a = build(:token_balance, token: build(:token, name: nil))
      token_balance_b = build(:token_balance, token: build(:token, name: "token name"))
      token_balance_c = build(:token_balance, token: build(:token, name: "token"))

      token_balances = [
        token_balance_a,
        token_balance_b,
        token_balance_c
      ]

      expected = [token_balance_c, token_balance_b, token_balance_a]

      assert AddressTokenBalanceView.sort_by_name(token_balances) == expected
    end

    test "considers capitalization" do
      token_balance_a = build(:token_balance, token: build(:token, name: "Token"))
      token_balance_b = build(:token_balance, token: build(:token, name: "atoken"))

      token_balances = [token_balance_a, token_balance_b]
      expected = [token_balance_b, token_balance_a]

      assert AddressTokenBalanceView.sort_by_name(token_balances) == expected
    end
  end

  describe "sort_by_usd_value_and_name/1" do
    test "sorts the given tokens by its name and usd_value" do
      token_balance_a = build(:token_balance, token: build(:token, name: "token name") |> Map.put(:usd_value, 2))
      token_balance_b = build(:token_balance, token: build(:token, name: "token") |> Map.put(:usd_value, 3))
      token_balance_c = build(:token_balance, token: build(:token, name: nil) |> Map.put(:usd_value, 2))
      token_balance_d = build(:token_balance, token: build(:token, name: "Atoken") |> Map.put(:usd_value, 1))
      token_balance_e = build(:token_balance, token: build(:token, name: "atoken") |> Map.put(:usd_value, nil))
      token_balance_f = build(:token_balance, token: build(:token, name: "Btoken") |> Map.put(:usd_value, nil))
      token_balance_g = build(:token_balance, token: build(:token, name: "Btoken") |> Map.put(:usd_value, 1))

      token_balances = [
        token_balance_a,
        token_balance_b,
        token_balance_c,
        token_balance_d,
        token_balance_e,
        token_balance_f,
        token_balance_g
      ]

      expected = [
        token_balance_b,
        token_balance_a,
        token_balance_c,
        token_balance_d,
        token_balance_g,
        token_balance_e,
        token_balance_f
      ]

      assert AddressTokenBalanceView.sort_by_usd_value_and_name(token_balances) == expected
    end
  end

  describe "balance_in_usd/1" do
    test "return balance in usd" do
      token =
        :token
        |> build(decimals: Decimal.new(0))
        |> Map.put(:usd_value, Decimal.new(3))

      token_balance = build(:token_balance, value: Decimal.new(10), token: token)

      result = AddressTokenBalanceView.balance_in_usd(token_balance)

      assert Decimal.cmp(result, 30) == :eq
    end

    test "return nil if usd_value is not present" do
      token =
        :token
        |> build(decimals: Decimal.new(0))
        |> Map.put(:usd_value, nil)

      token_balance = build(:token_balance, value: 10, token: token)

      assert AddressTokenBalanceView.balance_in_usd(token_balance) == nil
    end

    test "consider decimals when computing value" do
      token =
        :token
        |> build(decimals: Decimal.new(2))
        |> Map.put(:usd_value, Decimal.new(3))

      token_balance = build(:token_balance, value: Decimal.new(10), token: token)

      result = AddressTokenBalanceView.balance_in_usd(token_balance)

      assert Decimal.cmp(result, Decimal.from_float(0.3)) == :eq
    end
  end
end
