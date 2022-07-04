defmodule BlockScoutWeb.Tokens.SmartContractViewTest do
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
end
