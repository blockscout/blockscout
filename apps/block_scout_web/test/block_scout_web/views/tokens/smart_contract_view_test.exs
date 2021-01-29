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

  describe "writable?" do
    test "returns true when there is write function" do
      function = %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "upgradeTo",
        "inputs" => [%{"type" => "uint256", "name" => "version"}, %{"type" => "address", "name" => "implementation"}],
        "constant" => false
      }

      assert SmartContractView.writable?(function)
    end

    test "returns false when it is not a write function" do
      function = %{
        "type" => "function",
        "stateMutability" => "view",
        "payable" => false,
        "outputs" => [%{"type" => "uint256", "name" => ""}],
        "name" => "version",
        "inputs" => [],
        "constant" => true
      }

      refute SmartContractView.writable?(function)
    end

    test "returns false when there is no function" do
      function = %{}

      refute SmartContractView.writable?(function)
    end

    test "returns false when there function is nil" do
      function = nil

      refute SmartContractView.writable?(function)
    end
  end

  describe "outputs?" do
    test "returns true when there are outputs" do
      outputs = [%{"name" => "_narcoId", "type" => "uint256"}]

      assert SmartContractView.outputs?(outputs)
    end

    test "returns false when there are no outputs" do
      outputs = []

      refute SmartContractView.outputs?(outputs)
    end
  end

  describe "payable?" do
    test "returns true when there is payable function" do
      function = %{
        "type" => "function",
        "stateMutability" => "payable",
        "payable" => true,
        "outputs" => [],
        "name" => "upgradeToAndCall",
        "inputs" => [
          %{"type" => "uint256", "name" => "version"},
          %{"type" => "address", "name" => "implementation"},
          %{"type" => "bytes", "name" => "data"}
        ],
        "constant" => false
      }

      assert SmartContractView.payable?(function)
    end

    test "returns true when there is old-style payable function" do
      function = %{
        "type" => "function",
        "payable" => true,
        "outputs" => [],
        "name" => "upgradeToAndCall",
        "inputs" => [
          %{"type" => "uint256", "name" => "version"},
          %{"type" => "address", "name" => "implementation"},
          %{"type" => "bytes", "name" => "data"}
        ],
        "constant" => false
      }

      assert SmartContractView.payable?(function)
    end

    test "returns false when it is nonpayable function" do
      function = %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "transferProxyOwnership",
        "inputs" => [%{"type" => "address", "name" => "newOwner"}],
        "constant" => false
      }

      refute SmartContractView.payable?(function)
    end

    test "returns false when there is no function" do
      function = %{}

      refute SmartContractView.payable?(function)
    end

    test "returns false when function is nil" do
      function = nil

      refute SmartContractView.payable?(function)
    end
  end

  describe "nonpayable?" do
    test "returns true when there is nonpayable function" do
      function = %{
        "type" => "function",
        "stateMutability" => "nonpayable",
        "payable" => false,
        "outputs" => [],
        "name" => "transferProxyOwnership",
        "inputs" => [%{"type" => "address", "name" => "newOwner"}],
        "constant" => false
      }

      assert SmartContractView.nonpayable?(function)
    end

    test "returns true when there is old-style nonpayable function" do
      function = %{
        "type" => "function",
        "outputs" => [],
        "name" => "test",
        "inputs" => [%{"type" => "address", "name" => "newOwner"}],
        "constant" => false
      }

      assert SmartContractView.nonpayable?(function)
    end

    test "returns false when it is payable function" do
      function = %{
        "type" => "function",
        "stateMutability" => "payable",
        "payable" => true,
        "outputs" => [],
        "name" => "upgradeToAndCall",
        "inputs" => [
          %{"type" => "uint256", "name" => "version"},
          %{"type" => "address", "name" => "implementation"},
          %{"type" => "bytes", "name" => "data"}
        ],
        "constant" => false
      }

      refute SmartContractView.nonpayable?(function)
    end

    test "returns true when there is no function" do
      function = %{}

      refute SmartContractView.nonpayable?(function)
    end

    test "returns false when function is nil" do
      function = nil

      refute SmartContractView.nonpayable?(function)
    end
  end

  describe "address?" do
    test "returns true when the type is equal to the string 'address'" do
      type = "address"

      assert SmartContractView.address?(type)
    end

    test "returns true when the type is equal to the string 'address payable'" do
      type = "address payable"

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

  describe "values/2" do
    test "joins the values when it is a list of a given type" do
      values = [8, 6, 9, 2, 2, 37]

      assert SmartContractView.values(values, "type") == "8,6,9,2,2,37"
    end

    test "convert the value to string receiving a value and the 'address' type" do
      value = <<95, 38, 9, 115, 52, 182, 163, 43, 121, 81, 223, 97, 253, 12, 88, 3, 236, 93, 131, 84>>
      assert SmartContractView.values(value, "address") == "0x5f26097334b6a32b7951df61fd0c5803ec5d8354"
    end

    test "convert the value to string receiving a value and the 'address payable' type" do
      value = <<95, 38, 9, 115, 52, 182, 163, 43, 121, 81, 223, 97, 253, 12, 88, 3, 236, 93, 131, 84>>
      assert SmartContractView.values(value, "address payable") == "0x5f26097334b6a32b7951df61fd0c5803ec5d8354"
    end

    test "convert each value to string and join them when receiving 'address[]' as the type" do
      value = [
        <<95, 38, 9, 115, 52, 182, 163, 43, 121, 81, 223, 97, 253, 12, 88, 3, 236, 93, 131, 84>>,
        <<207, 38, 14, 163, 23, 85, 86, 55, 197, 95, 112, 229, 93, 186, 141, 90, 216, 65, 76, 176>>
      ]

      assert SmartContractView.values(value, "address[]") ==
               "0x5f26097334b6a32b7951df61fd0c5803ec5d8354,0xcf260ea317555637c55f70e55dba8d5ad8414cb0"
    end

    test "returns the value when the type is neither 'address' nor 'address payable'" do
      value = "POA"

      assert SmartContractView.values(value, "string") == "POA"
    end
  end
end
