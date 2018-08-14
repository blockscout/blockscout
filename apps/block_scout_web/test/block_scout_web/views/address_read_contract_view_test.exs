defmodule BlockScoutWeb.AddressReadContractViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressReadContractView

  describe "queryable?/1" do
    test "returns true if list of inputs is not empty" do
      assert AddressReadContractView.queryable?([%{"name" => "argument_name", "type" => "uint256"}]) == true
      assert AddressReadContractView.queryable?([]) == false
    end
  end

  describe "address?/1" do
    test "returns true if type equals `address`" do
      assert AddressReadContractView.address?("address") == true
      assert AddressReadContractView.address?("uint256") == false
    end
  end
end
