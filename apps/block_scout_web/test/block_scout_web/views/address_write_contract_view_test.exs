defmodule BlockScoutWeb.AddressWriteContractViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.AddressWriteContractView

  describe "queryable?/1" do
    test "returns true if list of inputs is not empty" do
      assert AddressWriteContractView.queryable?([%{"name" => "argument_name", "type" => "uint256"}]) == true
      assert AddressWriteContractView.queryable?([]) == false
    end
  end

  describe "address?/1" do
    test "returns true if type equals `address`" do
      assert AddressWriteContractView.address?("address") == true
      assert AddressWriteContractView.address?("uint256") == false
    end
  end
end
