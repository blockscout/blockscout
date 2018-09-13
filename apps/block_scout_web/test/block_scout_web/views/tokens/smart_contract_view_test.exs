defmodule BlockScoutWeb.SmartContractViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.SmartContractView

  describe "queryable?" do
    test "returns true when there are inputs" do
      inputs = [%{"name" => "_narcoId", "type" => "uint256"}]

      assert SmartContractView.queryable?(inputs)
    end

    test "returns false when there are no inputs" do
      inputs = []

      refute SmartContractView.queryable?(inputs)
    end
  end

  describe "address?" do
    test "returns true when the type is equal to the string 'address'" do
      type = "address"

      assert SmartContractView.address?(type)
    end

    test "returns false when the type is not equal the string 'address'" do
      type = "name"

      refute SmartContractView.address?(type)
    end
  end

  describe "named_argument?/1" do
    test "returns false when name is blank" do
      arguments = %{"name" => ""}

      refute SmartContractView.named_argument?(arguments)
    end

    test "returns false when name is nil" do
      arguments = %{"name" => nil}

      refute SmartContractView.named_argument?(arguments)
    end

    test "returns true when there is name" do
      arguments = %{"name" => "POA"}

      assert SmartContractView.named_argument?(arguments)
    end

    test "returns false arguments don't match" do
      arguments = nil

      refute SmartContractView.named_argument?(arguments)
    end
  end

  describe "values/1" do
    test "joins the values when it is a list" do
      values = [8, 6, 9, 2, 2, 37]

      assert SmartContractView.values(values) == "8,6,9,2,2,37"
    end

    test "returns the value" do
      value = "POA"

      assert SmartContractView.values(value) == "POA"
    end
  end
end
