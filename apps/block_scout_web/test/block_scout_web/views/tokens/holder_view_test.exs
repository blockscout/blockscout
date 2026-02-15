defmodule BlockScoutWeb.Tokens.HolderViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.Tokens.HolderView
  alias Explorer.Chain.{Address.TokenBalance, Token}

  doctest BlockScoutWeb.Tokens.HolderView, import: true

  describe "show_total_supply_percentage?/1" do
    test "returns false when the total supply is nil" do
      %Token{total_supply: total_supply} = build(:token, total_supply: nil)

      refute HolderView.show_total_supply_percentage?(total_supply)
    end

    test "returns false when the total supply is 0" do
      %Token{total_supply: total_supply} = build(:token, total_supply: 0)

      refute HolderView.show_total_supply_percentage?(total_supply)
    end

    test "returns true when the total supply is greater than 0" do
      %Token{total_supply: total_supply} = build(:token, total_supply: 1000)

      assert HolderView.show_total_supply_percentage?(total_supply)
    end
  end

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

    test "zero total_supply" do
      %Token{total_supply: total_supply} = build(:token, total_supply: 0)
      %TokenBalance{value: value} = build(:token_balance, value: 0)

      assert HolderView.total_supply_percentage(value, total_supply) == "N/A%"
    end

    test "decimal zero total_supply" do
      %Token{total_supply: total_supply} = build(:token, total_supply: Decimal.new(0))
      %TokenBalance{value: value} = build(:token_balance, value: 0)

      assert HolderView.total_supply_percentage(value, total_supply) == "N/A%"
    end
  end

  describe "format_token_balance_value/3" do
    test "formats according to token decimals when it's a ERC-20" do
      token = build(:token, type: "ERC-20", decimals: Decimal.new(2))
      token_balance = build(:token_balance, value: 2_000_000)

      assert HolderView.format_token_balance_value(token_balance.value, nil, token) == "20,000"
    end

    test "returns the value when it's ERC-721" do
      token = build(:token, type: "ERC-721")
      token_balance = build(:token_balance, value: 1)

      assert HolderView.format_token_balance_value(token_balance.value, nil, token) == 1
    end

    test "returns '*confidential*' for ERC-7984 tokens" do
      token = build(:token, type: "ERC-7984", decimals: Decimal.new(18))
      token_balance = build(:token_balance, value: 1_000_000)

      assert HolderView.format_token_balance_value(token_balance.value, nil, token) == "*confidential*"
    end
  end
end
