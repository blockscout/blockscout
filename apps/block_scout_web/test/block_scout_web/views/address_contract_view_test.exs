defmodule BlockScoutWeb.AddressContractViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressContractView

  doctest BlockScoutWeb.AddressContractView

  describe "format_optimization_text/1" do
    test "returns \"true\" for the boolean true" do
      assert AddressContractView.format_optimization_text(true) == "true"
    end

    test "returns \"false\" for the boolean false" do
      assert AddressContractView.format_optimization_text(false) == "false"
    end
  end
end
