defmodule BlockScoutWeb.AddressTokenBalanceViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressTokenBalanceView
  alias Explorer.Chain

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

  describe "balance_in_fiat/1" do
    test "return balance in fiat" do
      token =
        :token
        |> build(decimals: Decimal.new(0))
        |> Map.put(:fiat_value, Decimal.new(3))

      token_balance = build(:token_balance, value: Decimal.new(10), token: token)

      result = Chain.balance_in_fiat(token_balance)

      assert Decimal.compare(result, 30) == :eq
    end

    test "return nil if fiat_value is not present" do
      token =
        :token
        |> build(decimals: Decimal.new(0))
        |> Map.put(:fiat_value, nil)

      token_balance = build(:token_balance, value: 10, token: token)

      assert Chain.balance_in_fiat(token_balance) == nil
    end

    test "consider decimals when computing value" do
      token =
        :token
        |> build(decimals: Decimal.new(2))
        |> Map.put(:fiat_value, Decimal.new(3))

      token_balance = build(:token_balance, value: Decimal.new(10), token: token)

      result = Chain.balance_in_fiat(token_balance)

      assert Decimal.compare(result, Decimal.from_float(0.3)) == :eq
    end
  end
end
