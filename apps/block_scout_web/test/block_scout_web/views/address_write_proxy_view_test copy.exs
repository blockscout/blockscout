defmodule BlockScoutWeb.AddressWriteProxyViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressWriteProxyView

  describe "queryable?/1" do
    test "returns true if list of inputs is not empty" do
      assert AddressWriteProxyView.queryable?([%{"name" => "argument_name", "type" => "uint256"}]) == true
      assert AddressWriteProxyView.queryable?([]) == false
    end
  end

  describe "address?/1" do
    test "returns true if type equals `address`" do
      assert AddressWriteProxyView.address?("address") == true
      assert AddressWriteProxyView.address?("uint256") == false
    end
  end
end
