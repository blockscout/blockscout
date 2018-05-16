defmodule ExplorerWeb.CurrencyHelpersTest do
  use ExUnit.Case

  alias ExplorerWeb.CurrencyHelpers
  alias ExplorerWeb.ExchangeRates.USD

  doctest ExplorerWeb.CurrencyHelpers, import: true

  test "with nil it returns nil" do
    assert nil == CurrencyHelpers.format_usd_value(nil)
  end

  test "with USD.null() it returns nil" do
    assert nil == CurrencyHelpers.format_usd_value(USD.null())
  end
end
