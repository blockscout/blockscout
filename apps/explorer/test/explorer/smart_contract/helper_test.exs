defmodule Explorer.SmartContract.HelperTest do
  use ExUnit.Case, async: true

  use Explorer.DataCase
  alias Explorer.SmartContract.Helper

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

      assert Helper.payable?(function)
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

      assert Helper.payable?(function)
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

      refute Helper.payable?(function)
    end

    test "returns false when there is no function" do
      function = %{}

      refute Helper.payable?(function)
    end

    test "returns false when function is nil" do
      function = nil

      refute Helper.payable?(function)
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

      assert Helper.nonpayable?(function)
    end

    test "returns true when there is old-style nonpayable function" do
      function = %{
        "type" => "function",
        "outputs" => [],
        "name" => "test",
        "inputs" => [%{"type" => "address", "name" => "newOwner"}],
        "constant" => false
      }

      assert Helper.nonpayable?(function)
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

      refute Helper.nonpayable?(function)
    end

    test "returns true when there is no function" do
      function = %{}

      refute Helper.nonpayable?(function)
    end

    test "returns false when function is nil" do
      function = nil

      refute Helper.nonpayable?(function)
    end
  end
end
