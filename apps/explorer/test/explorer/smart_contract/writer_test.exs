defmodule Explorer.SmartContract.WriterTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.SmartContract.Writer

  @abi [
    %{
      "type" => "function",
      "stateMutability" => "nonpayable",
      "payable" => false,
      "outputs" => [],
      "name" => "upgradeTo",
      "inputs" => [%{"type" => "uint256", "name" => "version"}, %{"type" => "address", "name" => "implementation"}],
      "constant" => false
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "version",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "address", "name" => ""}],
      "name" => "implementation",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "address", "name" => ""}],
      "name" => "upgradeabilityOwner",
      "inputs" => [],
      "constant" => true
    },
    %{
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
    },
    %{
      "type" => "function",
      "stateMutability" => "nonpayable",
      "payable" => false,
      "outputs" => [],
      "name" => "transferProxyOwnership",
      "inputs" => [%{"type" => "address", "name" => "newOwner"}],
      "constant" => false
    },
    %{"type" => "fallback", "stateMutability" => "payable", "payable" => true},
    %{
      "type" => "event",
      "name" => "ProxyOwnershipTransferred",
      "inputs" => [
        %{"type" => "address", "name" => "previousOwner", "indexed" => false},
        %{"type" => "address", "name" => "newOwner", "indexed" => false}
      ],
      "anonymous" => false
    },
    %{
      "type" => "event",
      "name" => "Upgraded",
      "inputs" => [
        %{"type" => "uint256", "name" => "version", "indexed" => false},
        %{"type" => "address", "name" => "implementation", "indexed" => true}
      ],
      "anonymous" => false
    }
  ]

  @implementation_abi [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "extraReceiverAmount",
      "inputs" => [%{"type" => "address", "name" => "_receiver"}],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "bridgesAllowedLength",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "pure",
      "payable" => false,
      "outputs" => [%{"type" => "bytes4", "name" => ""}],
      "name" => "blockRewardContractId",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "mintedForAccountInBlock",
      "inputs" => [%{"type" => "address", "name" => "_account"}, %{"type" => "uint256", "name" => "_blockNumber"}],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "mintedForAccount",
      "inputs" => [%{"type" => "address", "name" => "_account"}],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "mintedInBlock",
      "inputs" => [%{"type" => "uint256", "name" => "_blockNumber"}],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "mintedTotally",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "pure",
      "payable" => false,
      "outputs" => [%{"type" => "address[1]", "name" => ""}],
      "name" => "bridgesAllowed",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "nonpayable",
      "payable" => false,
      "outputs" => [],
      "name" => "addExtraReceiver",
      "inputs" => [%{"type" => "uint256", "name" => "_amount"}, %{"type" => "address", "name" => "_receiver"}],
      "constant" => false
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "mintedTotallyByBridge",
      "inputs" => [%{"type" => "address", "name" => "_bridge"}],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "address", "name" => ""}],
      "name" => "extraReceiverByIndex",
      "inputs" => [%{"type" => "uint256", "name" => "_index"}],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "bridgeAmount",
      "inputs" => [%{"type" => "address", "name" => "_bridge"}],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "uint256", "name" => ""}],
      "name" => "extraReceiversLength",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "nonpayable",
      "payable" => false,
      "outputs" => [%{"type" => "address[]", "name" => ""}, %{"type" => "uint256[]", "name" => ""}],
      "name" => "reward",
      "inputs" => [%{"type" => "address[]", "name" => "benefactors"}, %{"type" => "uint16[]", "name" => "kind"}],
      "constant" => false
    },
    %{
      "type" => "event",
      "name" => "AddedReceiver",
      "inputs" => [
        %{"type" => "uint256", "name" => "amount", "indexed" => false},
        %{"type" => "address", "name" => "receiver", "indexed" => true},
        %{"type" => "address", "name" => "bridge", "indexed" => true}
      ],
      "anonymous" => false
    }
  ]

  doctest Explorer.SmartContract.Writer

  setup :verify_on_exit!

  describe "write_functions/1" do
    test "fetches the smart contract write functions" do
      smart_contract =
        insert(
          :smart_contract,
          abi: @abi
        )

      response = Writer.write_functions(smart_contract.address_hash)

      assert [
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "payable" => false,
                 "outputs" => [],
                 "name" => "upgradeTo",
                 "inputs" => [
                   %{"type" => "uint256", "name" => "version"},
                   %{"type" => "address", "name" => "implementation"}
                 ],
                 "constant" => false
               },
               %{
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
               },
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "payable" => false,
                 "outputs" => [],
                 "name" => "transferProxyOwnership",
                 "inputs" => [%{"type" => "address", "name" => "newOwner"}],
                 "constant" => false
               },
               %{"type" => "fallback", "stateMutability" => "payable", "payable" => true}
             ] = response
    end
  end

  describe "write_functions_proxy/1" do
    test "fetches the smart contract proxy write functions" do
      proxy_smart_contract =
        insert(:smart_contract,
          abi: @abi
        )

      implementation_contract_address = insert(:contract_address)

      insert(:smart_contract,
        address_hash: implementation_contract_address.hash,
        abi: @implementation_abi
      )

      implementation_contract_address_hash_string =
        Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

      response = Writer.write_functions_proxy("0x" <> implementation_contract_address_hash_string)

      assert [
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "payable" => false,
                 "outputs" => [],
                 "name" => "addExtraReceiver",
                 "inputs" => [
                   %{"type" => "uint256", "name" => "_amount"},
                   %{"type" => "address", "name" => "_receiver"}
                 ],
                 "constant" => false
               },
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "payable" => false,
                 "outputs" => [%{"type" => "address[]", "name" => ""}, %{"type" => "uint256[]", "name" => ""}],
                 "name" => "reward",
                 "inputs" => [
                   %{"type" => "address[]", "name" => "benefactors"},
                   %{"type" => "uint16[]", "name" => "kind"}
                 ],
                 "constant" => false
               }
             ] = response
    end
  end
end
