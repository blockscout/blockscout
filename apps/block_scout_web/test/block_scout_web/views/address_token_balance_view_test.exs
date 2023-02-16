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

      token_balances = [{token_balance_a, token_balance_a.token}, {token_balance_b, token_balance_b.token}]

      assert AddressTokenBalanceView.filter_by_type(token_balances, "ERC-20") == [
               {token_balance_a, token_balance_a.token}
             ]
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

  describe "sort_by_fiat_value_and_name/1" do
    test "sorts the given tokens by its name and fiat_value" do
      token_balance_a =
        build(:token_balance,
          token: build(:token, name: "token name", decimals: Decimal.new(18)) |> Map.put(:fiat_value, Decimal.new(2)),
          value: Decimal.new(100_500)
        )

      token_balance_b =
        build(:token_balance,
          token:
            build(:token, name: "token", decimals: Decimal.new(18)) |> Map.put(:fiat_value, Decimal.from_float(3.45)),
          value: Decimal.new(100_500)
        )

      token_balance_c =
        build(:token_balance,
          token: build(:token, name: nil, decimals: Decimal.new(18)) |> Map.put(:fiat_value, Decimal.new(2)),
          value: Decimal.new(100_500)
        )

      token_balance_d =
        build(:token_balance,
          token: build(:token, name: "Atoken", decimals: Decimal.new(18)) |> Map.put(:fiat_value, Decimal.new(1)),
          value: Decimal.new(100_500)
        )

      token_balance_e =
        build(:token_balance,
          token: build(:token, name: "atoken", decimals: Decimal.new(18)) |> Map.put(:fiat_value, nil),
          value: Decimal.new(100_500)
        )

      token_balance_f =
        build(:token_balance,
          token: build(:token, name: "Btoken", decimals: Decimal.new(18)) |> Map.put(:fiat_value, nil),
          value: Decimal.new(100_500)
        )

      token_balance_g =
        build(:token_balance,
          token: build(:token, name: "Btoken", decimals: Decimal.new(18)) |> Map.put(:fiat_value, Decimal.new(1)),
          value: Decimal.new(100_500)
        )

      token_balances = [
        {token_balance_a, token_balance_a.token},
        {token_balance_b, token_balance_b.token},
        {token_balance_c, token_balance_c.token},
        {token_balance_d, token_balance_d.token},
        {token_balance_e, token_balance_e.token},
        {token_balance_f, token_balance_f.token},
        {token_balance_g, token_balance_g.token}
      ]

      expected = [
        {token_balance_b, token_balance_b.token},
        {token_balance_a, token_balance_a.token},
        {token_balance_c, token_balance_c.token},
        {token_balance_d, token_balance_d.token},
        {token_balance_g, token_balance_g.token},
        {token_balance_e, token_balance_e.token},
        {token_balance_f, token_balance_f.token}
      ]

      assert AddressTokenBalanceView.sort_by_fiat_value_and_name(token_balances) == expected
    end
  end

  describe "balance_in_usd/1" do
    test "return balance in usd" do
      token =
        :token
        |> build(decimals: Decimal.new(0))
        |> Map.put(:fiat_value, Decimal.new(3))

      token_balance = build(:token_balance, value: Decimal.new(10), token: token)

      result = Chain.balance_in_usd(token_balance)

      assert Decimal.compare(result, 30) == :eq
    end

    test "return nil if fiat_value is not present" do
      token =
        :token
        |> build(decimals: Decimal.new(0))
        |> Map.put(:fiat_value, nil)

      token_balance = build(:token_balance, value: 10, token: token)

      assert Chain.balance_in_usd(token_balance) == nil
    end

    test "consider decimals when computing value" do
      token =
        :token
        |> build(decimals: Decimal.new(2))
        |> Map.put(:fiat_value, Decimal.new(3))

      token_balance = build(:token_balance, value: Decimal.new(10), token: token)

      result = Chain.balance_in_usd(token_balance)

      assert Decimal.compare(result, Decimal.from_float(0.3)) == :eq
    end
  end
end
