defmodule BlockScoutWeb.Tokens.HolderViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.Tokens.HolderView
  alias Explorer.Chain.{Address.TokenBalance, Token}

  doctest BlockScoutWeb.Tokens.HolderView, import: true

  describe "total_supply_percentage/2" do
    test "returns the percentage of the Token total supply" do
      %Token{total_supply: total_supply} = build(:token, total_supply: 1000)
      %TokenBalance{value: value} = build(:token_balance, value: 200)

      assert HolderView.total_supply_percentage(value, total_supply) == "20.0000%"
    end

    test "considers 4 decimals" do
      %Token{total_supply: total_supply} = build(:token, total_supply: 100_000_009)
      %TokenBalance{value: value} = build(:token_balance, value: 500)

      assert HolderView.total_supply_percentage(value, total_supply) == "0.0005%"
    end
  end

  describe "format_token_balance_value/1" do
    test "formats according to token decimals when it's a ERC-20" do
      token = build(:token, type: "ERC-20", decimals: 2)
      token_balance = build(:token_balance, value: 2_000_000)

      assert HolderView.format_token_balance_value(token_balance.value, token) == "20,000"
    end

    test "returns the value when it's ERC-721" do
      token = build(:token, type: "ERC-721")
      token_balance = build(:token_balance, value: 1)

      assert HolderView.format_token_balance_value(token_balance.value, token) == 1
    end
  end
end
