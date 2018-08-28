defmodule BlockScoutWeb.AddressTokenBalanceViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressTokenBalanceView

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
end
