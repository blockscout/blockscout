defmodule ExplorerWeb.AddresstransactionViewTest do
  use ExplorerWeb.ConnCase, async: true

  alias ExplorerWeb.AddressTransactionView

  doctest ExplorerWeb.AddressTransactionView

  describe "formatted_token_amount/1" do
    test "formats the amount as value considering the given decimals" do
      amount = Decimal.new(205_000_000_000_000)
      decimals = 12

      assert AddressTransactionView.formatted_token_amount(amount, decimals) == "205"
    end

    test "considers the decimal places according to the given decimals" do
      amount = Decimal.new(205_000)
      decimals = 12

      assert AddressTransactionView.formatted_token_amount(amount, decimals) == "0.000000205"
    end

    test "does not consider right zeros in decimal places" do
      amount = Decimal.new(90_000_000)
      decimals = 6

      assert AddressTransactionView.formatted_token_amount(amount, decimals) == "90"
    end

    test "returns the full number when there is no right zeros in decimal places" do
      amount = Decimal.new(9_324_876)
      decimals = 6

      assert AddressTransactionView.formatted_token_amount(amount, decimals) == "9.324876"
    end
  end
end
