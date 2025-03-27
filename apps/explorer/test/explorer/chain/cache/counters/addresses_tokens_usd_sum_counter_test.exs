defmodule Explorer.Chain.Cache.Counters.AddressTokensUsdSumTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.AddressTokensUsdSum

  test "populates the cache with the sum of address tokens" do
    address = insert(:address)

    address_current_token_balance =
      build(:token_balance,
        token: build(:token, name: "token name", decimals: Decimal.new(18)) |> Map.put(:fiat_value, Decimal.new(10)),
        value: Decimal.mult(Decimal.new(100_500), Decimal.from_float(:math.pow(10, 18)))
      )

    address_current_token_balance_2 =
      build(:token_balance,
        token: build(:token, name: "token name", decimals: Decimal.new(18)) |> Map.put(:fiat_value, Decimal.new(10)),
        value: Decimal.mult(Decimal.new(100_500), Decimal.from_float(:math.pow(10, 18)))
      )

    AddressTokensUsdSum.fetch(address.hash, [
      address_current_token_balance,
      address_current_token_balance_2
    ])

    Process.sleep(200)

    assert AddressTokensUsdSum.fetch(address.hash, [
             address_current_token_balance,
             address_current_token_balance_2
           ]) ==
             Decimal.new(2_010_000)
  end
end
