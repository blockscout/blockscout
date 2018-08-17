defmodule BlockScoutWeb.AddressTokenBalanceViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressTokenBalanceView

  describe "sort_by_name/1" do
    test "sorts the given tokens by its name" do
      token_a = build(:token, name: "token name")
      token_b = build(:token, name: "token")
      token_c = build(:token, name: "atoken")

      assert AddressTokenBalanceView.sort_by_name([token_a, token_b, token_c]) == [token_c, token_b, token_a]
    end

    test "considers nil values in the bottom of the list" do
      token_a = build(:token, name: nil)
      token_b = build(:token, name: "token name")
      token_c = build(:token, name: "token")

      assert AddressTokenBalanceView.sort_by_name([token_a, token_b, token_c]) == [token_c, token_b, token_a]
    end

    test "considers capitalization" do
      token_a = build(:token, name: "Token")
      token_b = build(:token, name: "atoken")

      assert AddressTokenBalanceView.sort_by_name([token_a, token_b]) == [token_b, token_a]
    end
  end
end
