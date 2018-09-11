defmodule BlockScoutWeb.AddressTokenViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressTokenView

  describe "number_of_transfers/1" do
    test "returns the singular form when there is only one transfer" do
      token = %{number_of_transfers: 1}

      assert AddressTokenView.number_of_transfers(token) == "1 transfer"
    end

    test "returns the plural form when there is more than one transfer" do
      token = %{number_of_transfers: 2}

      assert AddressTokenView.number_of_transfers(token) == "2 transfers"
    end

    test "returns the plural form when there are 0 transfers" do
      token = %{number_of_transfers: 0}

      assert AddressTokenView.number_of_transfers(token) == "0 transfers"
    end
  end
end
