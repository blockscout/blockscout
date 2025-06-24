defmodule Explorer.SmartContract.HelperTest do
  use ExUnit.Case, async: true
  use Explorer.DataCase

  import Mox
  setup :verify_on_exit!

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

  describe "read_with_wallet_method?" do
    test "doesn't return payable method with output in the read tab" do
      function = %{
        "type" => "function",
        "stateMutability" => "payable",
        "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
        "name" => "returnaddress",
        "inputs" => []
      }

      refute Helper.read_with_wallet_method?(function)
    end

    test "doesn't return payable method with no output in the read tab" do
      function = %{
        "type" => "function",
        "stateMutability" => "payable",
        "outputs" => [],
        "name" => "returnaddress",
        "inputs" => []
      }

      refute Helper.read_with_wallet_method?(function)
    end
  end

  describe "get_binary_string_from_contract_getter/4" do
    # TODO: https://github.com/blockscout/blockscout/issues/12544
    # test "returns bytes starting from 0x" do
    #   abi = [
    #     %{
    #       "type" => "function",
    #       "stateMutability" => "view",
    #       "outputs" => [%{"type" => "bytes16", "name" => "data", "internalType" => "bytes16"}],
    #       "name" => "getData",
    #       "inputs" => []
    #     }
    #   ]

    #   expect(
    #     EthereumJSONRPC.Mox,
    #     :json_rpc,
    #     fn [
    #          %{
    #            id: id,
    #            method: "eth_call",
    #            params: [%{data: "0x3bc5de30", to: "0x0000000000000000000000000000000000000001"}, _]
    #          }
    #        ],
    #        _options ->
    #       {:ok,
    #        [%{id: id, jsonrpc: "2.0", result: "0x3078313233343536373839404142434400000000000000000000000000000000"}]}
    #     end
    #   )

    #   assert "0x30783132333435363738394041424344" ==
    #            Helper.get_binary_string_from_contract_getter(
    #              "3bc5de30",
    #              "0x0000000000000000000000000000000000000001",
    #              abi
    #            )
    # end

    test "returns address" do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "data", "internalType" => "address"}],
          "name" => "getAddress",
          "inputs" => []
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0x38cc4831", to: "0x0000000000000000000000000000000000000001"}, _]
             }
           ],
           _options ->
          {:ok,
           [%{id: id, jsonrpc: "2.0", result: "0x0000000000000000000000003078000000000000000000000000000000000001"}]}
        end
      )

      assert "0x3078000000000000000000000000000000000001" ==
               Helper.get_binary_string_from_contract_getter(
                 "38cc4831",
                 "0x0000000000000000000000000000000000000001",
                 abi
               )
    end
  end
end
