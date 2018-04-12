defmodule ExplorerWeb.WeiConverterTest do
  use ExUnit.Case

  alias ExplorerWeb.WeiConverter

  test "it converts wei to ether correctly" do
    wei = Decimal.new(239_047_000_000_000)
    expected_value = Decimal.new(0.000239047)

    assert WeiConverter.to_ether(wei) == expected_value
  end

  test "it converts wei to Gwei correctly" do
    wei = Decimal.new(239_047_123_000_000)
    expected_value = Decimal.new(239_047.123)

    assert WeiConverter.to_gwei(wei) == expected_value
  end
end
