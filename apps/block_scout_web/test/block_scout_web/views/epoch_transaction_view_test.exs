defmodule BlockScoutWeb.EpochTransactionViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.EpochTransactionView
  alias Explorer.Chain.Wei

  test "wei_to_ether_rounded/1" do
    for {decimal, wei_value} <- [
          {Decimal.new(0.00004), 40_000_000_000_000},
          {Decimal.new(0.12), 123_000_000_000_000_000},
          {Decimal.new(0.13), 125_000_000_000_000_000},
          {Decimal.new(0.001), 1_000_000_000_000_000},
          {Decimal.new(0.001), 1_230_000_000_000_000},
          {Decimal.new(0.002), 1_500_000_000_000_000},
          {Decimal.new(0.0002), 150_000_000_000_000},
          {Decimal.round(Decimal.new(0), 2), 400_000_000_000}
        ] do
      {:ok, wei} = Wei.cast(wei_value)
      rounded = EpochTransactionView.wei_to_ether_rounded(wei)

      assert decimal == rounded, "#{wei_value} should be rounded as #{decimal}, but instead it was #{rounded}"
    end
  end
end
