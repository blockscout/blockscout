defmodule Explorer.Counters.AddressTokenUsdSumTest do
  use Explorer.DataCase

  alias Explorer.Counters.AddressTokenUsdSum

  test "populates the cache with the sum of address tokens" do
    address = insert(:address)

    address_current_token_balance =
      build(:token_balance,
        token: build(:token, name: "token name", decimals: Decimal.new(18)) |> Map.put(:usd_value, Decimal.new(10)),
        value: Decimal.mult(Decimal.new(100_500), Decimal.from_float(:math.pow(10, 18)))
      )

    address_current_token_balance_2 =
      build(:token_balance,
        token: build(:token, name: "token name", decimals: Decimal.new(18)) |> Map.put(:usd_value, Decimal.new(10)),
        value: Decimal.mult(Decimal.new(100_500), Decimal.from_float(:math.pow(10, 18)))
      )

    AddressTokenUsdSum.fetch(address.hash, [
      {address_current_token_balance, address_current_token_balance.token},
      {address_current_token_balance_2, address_current_token_balance_2.token}
    ])

    Process.sleep(200)

    assert AddressTokenUsdSum.fetch(address.hash, [
             {address_current_token_balance, address_current_token_balance.token},
             {address_current_token_balance_2, address_current_token_balance_2.token}
           ]) ==
             Decimal.new(2_010_000)
  end
end
