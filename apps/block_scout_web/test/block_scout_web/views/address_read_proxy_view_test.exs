defmodule BlockScoutWeb.AddressReadProxyViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressReadProxyView

  describe "queryable?/1" do
    test "returns true if list of inputs is not empty" do
      assert AddressReadProxyView.queryable?([%{"name" => "argument_name", "type" => "uint256"}]) == true
      assert AddressReadProxyView.queryable?([]) == false
    end
  end

  describe "address?/1" do
    test "returns true if type equals `address`" do
      assert AddressReadProxyView.address?("address") == true
      assert AddressReadProxyView.address?("uint256") == false
    end
  end
end
