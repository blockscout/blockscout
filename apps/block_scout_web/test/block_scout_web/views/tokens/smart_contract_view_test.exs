defmodule BlockScoutWeb.SmartContractViewTest do
  use BlockScoutWeb.ConnCase, async: true

  @max_size Enum.at(Tuple.to_list(Application.get_env(:block_scout_web, :max_size_to_show_array_as_is)), 0)

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

    test "returns true if list of inputs is not empty" do
      assert SmartContractView.queryable?([%{"name" => "argument_name", "type" => "uint256"}]) == true
      assert SmartContractView.queryable?([]) == false
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

  describe "address?" do
    test "returns true if type equals `address`" do
      assert SmartContractView.address?("address") == true
      assert SmartContractView.address?("uint256") == false
    end

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

  defp wrap_it(output, length \\ -1) do
    if length > @max_size do
      "<details class=\"py-2 word-break-all\"><summary>Click to view</summary>#{output}</details>"
    else
      "<span class=\"word-break-all\" style=\"line-height: 3;\">#{output}</span>"
    end
  end

  describe "values_only/2" do
    test "joins the values when it is a list of a given type" do
      values = [8, 6, 9, 2, 2, 37]
      assert SmartContractView.values_only(values, "type", nil) == wrap_it("[8, 6, 9, 2, 2, 37]", length(values))
    end

    test "convert the value to string receiving a value and the 'address' type" do
      value = <<95, 38, 9, 115, 52, 182, 163, 43, 121, 81, 223, 97, 253, 12, 88, 3, 236, 93, 131, 84>>

      assert SmartContractView.values_only(value, "address", nil) ==
               wrap_it("0x5f26097334b6a32b7951df61fd0c5803ec5d8354")
    end

    test "convert the value to string receiving a value and the :address type" do
      value = <<95, 38, 9, 115, 52, 182, 163, 43, 121, 81, 223, 97, 253, 12, 88, 3, 236, 93, 131, 84>>

      assert SmartContractView.values_only(value, :address, nil) ==
               wrap_it("0x5f26097334b6a32b7951df61fd0c5803ec5d8354")
    end

    test "convert the value to string receiving a value and the 'address payable' type" do
      value = <<95, 38, 9, 115, 52, 182, 163, 43, 121, 81, 223, 97, 253, 12, 88, 3, 236, 93, 131, 84>>

      assert SmartContractView.values_only(value, "address payable", nil) ==
               wrap_it("0x5f26097334b6a32b7951df61fd0c5803ec5d8354")
    end

    test "convert each value to string and join them when receiving 'address[]' as the type" do
      value = [
        <<95, 38, 9, 115, 52, 182, 163, 43, 121, 81, 223, 97, 253, 12, 88, 3, 236, 93, 131, 84>>,
        <<207, 38, 14, 163, 23, 85, 86, 55, 197, 95, 112, 229, 93, 186, 141, 90, 216, 65, 76, 176>>
      ]

      assert SmartContractView.values_only(value, "address[]", nil) ==
               wrap_it(
                 "[0x5f26097334b6a32b7951df61fd0c5803ec5d8354, 0xcf260ea317555637c55f70e55dba8d5ad8414cb0]",
                 length(value)
               )
    end

    test "returns the value when the type is neither 'address' nor 'address payable'" do
      value = "POA"

      assert SmartContractView.values_only(value, "string", nil) == wrap_it("POA")
    end

    test "returns the value when the type is :string" do
      value = "POA"

      assert SmartContractView.values_only(value, :string, nil) == wrap_it("POA")
    end

    test "returns the value when the type is :bytes" do
      value =
        "0x00050000a7823d6f1e31569f51861e345b30c6bebf70ebe700000000000019f2f6a78083ca3e2a662d6dd1703c939c8ace2e268d88ad09518695c6c3712ac10a214be5109a65567100061a800101806401125e4cfb0000000000000000000000000ae055097c6d159879521c384f1d2123d1f195e60000000000000000000000004c26ca0dc82a6e7bb00b8815a65985b67c0d30d3000000000000000000000000000000000000000000000002b5598f488fb733c9"

      assert SmartContractView.values_only(value, :bytes, nil) ==
               wrap_it(
                 "0x00050000a7823d6f1e31569f51861e345b30c6bebf70ebe700000000000019f2f6a78083ca3e2a662d6dd1703c939c8ace2e268d88ad09518695c6c3712ac10a214be5109a65567100061a800101806401125e4cfb0000000000000000000000000ae055097c6d159879521c384f1d2123d1f195e60000000000000000000000004c26ca0dc82a6e7bb00b8815a65985b67c0d30d3000000000000000000000000000000000000000000000002b5598f488fb733c9"
               )
    end

    test "returns the value when the type is boolean" do
      value = "true"

      assert SmartContractView.values_only(value, "bool", nil) == wrap_it("true")
    end

    test "returns the value when the type is :bool" do
      value = "true"

      assert SmartContractView.values_only(value, :bool, nil) == wrap_it("true")
    end

    test "returns the value when the type is bytes4" do
      value = <<228, 184, 12, 77>>

      assert SmartContractView.values_only(value, "bytes4", nil) == wrap_it("0xe4b80c4d")
    end

    test "returns the value when the type is bytes32" do
      value =
        <<156, 209, 70, 119, 249, 170, 85, 105, 179, 187, 179, 81, 252, 214, 125, 17, 21, 170, 86, 58, 225, 98, 66, 118,
          211, 212, 230, 127, 179, 214, 249, 38>>

      assert SmartContractView.values_only(value, "bytes32", nil) ==
               wrap_it("0x9cd14677f9aa5569b3bbb351fcd67d1115aa563ae1624276d3d4e67fb3d6f926")
    end

    test "returns the value when the type is uint(n) and value is 0" do
      value = "0"

      assert SmartContractView.values_only(value, "uint64", nil) == wrap_it("0")
    end

    test "returns the value when the type is int(n) and value is 0" do
      value = "0"

      assert SmartContractView.values_only(value, "int64", nil) == wrap_it("0")
    end
  end
end
