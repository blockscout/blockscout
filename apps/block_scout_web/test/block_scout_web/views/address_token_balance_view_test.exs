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
end
