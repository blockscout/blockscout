# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SmartContractTest do
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog
  import Mox
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Chain.SmartContract.VerificationStatus

  doctest Explorer.Chain.SmartContract

  setup :verify_on_exit!
  setup :set_mox_global

  describe "create_smart_contract/1" do
    setup do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      created_contract_address =
        insert(
          :address,
          hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
          contract_code: smart_contract_bytecode
        )

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: created_contract_address,
        created_contract_code: smart_contract_bytecode,
        block_number: transaction.block_number,
        transaction_index: transaction.index
      )

      valid_attrs = %{
        address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
        name: "SimpleStorage",
        compiler_version: "0.4.23",
        optimization: false,
        contract_source_code:
          "pragma solidity ^0.4.23; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }",
        abi: [
          %{
            "constant" => false,
            "inputs" => [%{"name" => "x", "type" => "uint256"}],
            "name" => "set",
            "outputs" => [],
            "payable" => false,
            "stateMutability" => "nonpayable",
            "type" => "function"
          },
          %{
            "constant" => true,
            "inputs" => [],
            "name" => "get",
            "outputs" => [%{"name" => "", "type" => "uint256"}],
            "payable" => false,
            "stateMutability" => "view",
            "type" => "function"
          }
        ]
      }

      {:ok, valid_attrs: valid_attrs, address: created_contract_address}
    end

    test "with valid data creates a smart contract", %{valid_attrs: valid_attrs} do
      assert {:ok, %SmartContract{} = smart_contract} = SmartContract.create_smart_contract(valid_attrs)
      assert smart_contract.name == "SimpleStorage"
      assert smart_contract.compiler_version == "0.4.23"
      assert smart_contract.optimization == false
      assert smart_contract.contract_source_code != ""
      assert smart_contract.abi != ""

      assert Repo.get_by(
               Address.Name,
               address_hash: smart_contract.address_hash,
               name: smart_contract.name,
               primary: true
             )
    end

    test "clears an existing primary name and sets the new one", %{valid_attrs: valid_attrs, address: address} do
      insert(:address_name, address: address, primary: true)
      assert {:ok, %SmartContract{} = smart_contract} = SmartContract.create_smart_contract(valid_attrs)

      assert Repo.get_by(
               Address.Name,
               address_hash: smart_contract.address_hash,
               name: smart_contract.name,
               primary: true
             )
    end

    test "trims whitespace from address name", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | name: "     SimpleStorage     "}
      assert {:ok, _} = SmartContract.create_smart_contract(attrs)
      assert Repo.get_by(Address.Name, name: "SimpleStorage")
    end

    test "sets the address verified field to true", %{valid_attrs: valid_attrs} do
      assert {:ok, %SmartContract{} = smart_contract} = SmartContract.create_smart_contract(valid_attrs)

      assert Repo.get_by(Address, hash: smart_contract.address_hash).verified == true
    end

    test "returns an error tuple (does not raise) when a non-primary Multi step fails", %{valid_attrs: valid_attrs} do
      # An additional source is inserted under a string-keyed Multi step
      # ("smart_contract_additional_source_0"), which the result `case` used to leave
      # unmatched -> CaseClauseError. An invalid additional source must now surface as a
      # clean error tuple instead of crashing the verification worker.
      invalid_secondary_sources = [
        %{
          file_name: "storage.sol",
          # contract_source_code intentionally omitted -> invalid changeset
          address_hash: valid_attrs.address_hash
        }
      ]

      log =
        capture_log(fn ->
          assert {:error, %Ecto.Changeset{valid?: false}} =
                   SmartContract.create_smart_contract(valid_attrs, [], invalid_secondary_sources)
        end)

      assert log =~ "Failed to create smart contract"
      # transaction rolled back -> no contract persisted
      refute Repo.get_by(SmartContract, address_hash: valid_attrs.address_hash)
    end
  end

  describe "create_or_update_smart_contract/3" do
    setup do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      address =
        insert(
          :address,
          hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
          contract_code: smart_contract_bytecode
        )

      valid_attrs = %{
        address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
        name: "SimpleStorage",
        compiler_version: "0.4.23",
        optimization: false,
        contract_source_code:
          "pragma solidity ^0.4.23; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }",
        abi: [%{"type" => "function", "name" => "get", "inputs" => [], "outputs" => []}],
        partially_verified: false,
        external_libraries: [],
        secondary_sources: []
      }

      {:ok, valid_attrs: valid_attrs, address: address}
    end

    test "reconciles pending verification statuses to passed on successful verification", %{
      valid_attrs: valid_attrs,
      address: address
    } do
      {:ok, _} = VerificationStatus.insert_status("pending-uid", :pending, to_string(address.hash))

      assert {:ok, %SmartContract{}} = SmartContract.create_or_update_smart_contract(address.hash, valid_attrs, false)

      assert Repo.get_by(VerificationStatus, uid: "pending-uid").status == 1
    end

    test "does not reconcile pending statuses when verification does not succeed", %{address: address} do
      initial = Application.get_env(:block_scout_web, :contract) || []

      Application.put_env(
        :block_scout_web,
        :contract,
        Keyword.merge(initial, partial_reverification_disabled: true)
      )

      on_exit(fn -> Application.put_env(:block_scout_web, :contract, initial) end)

      # existing partially verified contract -> re-verifying with a partial one is rejected
      insert(:smart_contract, address_hash: address.hash, partially_verified: true, contract_code_md5: "123")

      {:ok, _} = VerificationStatus.insert_status("pending-uid", :pending, to_string(address.hash))

      attrs = %{partially_verified: true, external_libraries: [], secondary_sources: []}

      assert {:error, _} = SmartContract.create_or_update_smart_contract(address.hash, attrs, false)

      assert Repo.get_by(VerificationStatus, uid: "pending-uid").status == 0
    end
  end

  describe "update_smart_contract/1" do
    setup do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      created_contract_address =
        insert(
          :address,
          hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
          contract_code: smart_contract_bytecode
        )

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: created_contract_address,
        created_contract_code: smart_contract_bytecode,
        block_number: transaction.block_number,
        transaction_index: transaction.index
      )

      valid_attrs = %{
        address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
        name: "SimpleStorage",
        compiler_version: "0.4.23",
        optimization: false,
        contract_source_code:
          "pragma solidity ^0.4.23; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }",
        abi: [
          %{
            "constant" => false,
            "inputs" => [%{"name" => "x", "type" => "uint256"}],
            "name" => "set",
            "outputs" => [],
            "payable" => false,
            "stateMutability" => "nonpayable",
            "type" => "function"
          },
          %{
            "constant" => true,
            "inputs" => [],
            "name" => "get",
            "outputs" => [%{"name" => "", "type" => "uint256"}],
            "payable" => false,
            "stateMutability" => "view",
            "type" => "function"
          }
        ],
        partially_verified: true
      }

      secondary_sources = [
        %{
          file_name: "storage.sol",
          contract_source_code:
            "pragma solidity >=0.7.0 <0.9.0;contract Storage {uint256 number;function store(uint256 num) public {number = num;}function retrieve_() public view returns (uint256){return number;}}",
          address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c"
        },
        %{
          file_name: "storage_1.sol",
          contract_source_code:
            "pragma solidity >=0.7.0 <0.9.0;contract Storage_1 {uint256 number;function store(uint256 num) public {number = num;}function retrieve_() public view returns (uint256){return number;}}",
          address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c"
        }
      ]

      changed_sources = [
        %{
          file_name: "storage_2.sol",
          contract_source_code:
            "pragma solidity >=0.7.0 <0.9.0;contract Storage_2 {uint256 number;function store(uint256 num) public {number = num;}function retrieve_() public view returns (uint256){return number;}}",
          address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c"
        },
        %{
          file_name: "storage_3.sol",
          contract_source_code:
            "pragma solidity >=0.7.0 <0.9.0;contract Storage_3 {uint256 number;function store(uint256 num) public {number = num;}function retrieve_() public view returns (uint256){return number;}}",
          address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c"
        }
      ]

      _ = SmartContract.create_smart_contract(valid_attrs, [], secondary_sources)

      {:ok,
       valid_attrs: valid_attrs,
       address: created_contract_address,
       secondary_sources: secondary_sources,
       changed_sources: changed_sources}
    end

    test "change partially_verified field", %{valid_attrs: valid_attrs, address: address} do
      sc_before_call = Repo.get_by(SmartContract, address_hash: address.hash)
      assert sc_before_call.name == Map.get(valid_attrs, :name)
      assert sc_before_call.partially_verified == Map.get(valid_attrs, :partially_verified)

      assert {:ok, %SmartContract{}} =
               SmartContract.update_smart_contract(%{
                 address_hash: address.hash,
                 partially_verified: false,
                 contract_source_code: "new code"
               })

      sc_after_call = Repo.get_by(SmartContract, address_hash: address.hash)
      assert sc_after_call.name == Map.get(valid_attrs, :name)
      assert sc_after_call.partially_verified == false
      assert sc_after_call.compiler_version == Map.get(valid_attrs, :compiler_version)
      assert sc_after_call.optimization == Map.get(valid_attrs, :optimization)
      assert sc_after_call.contract_source_code == "new code"
    end

    test "check nothing changed", %{valid_attrs: valid_attrs, address: address} do
      sc_before_call = Repo.get_by(SmartContract, address_hash: address.hash)
      assert sc_before_call.name == Map.get(valid_attrs, :name)
      assert sc_before_call.partially_verified == Map.get(valid_attrs, :partially_verified)

      assert {:ok, %SmartContract{}} = SmartContract.update_smart_contract(%{address_hash: address.hash})

      sc_after_call = Repo.get_by(SmartContract, address_hash: address.hash)
      assert sc_after_call.name == Map.get(valid_attrs, :name)
      assert sc_after_call.partially_verified == Map.get(valid_attrs, :partially_verified)
      assert sc_after_call.compiler_version == Map.get(valid_attrs, :compiler_version)
      assert sc_after_call.optimization == Map.get(valid_attrs, :optimization)
      assert sc_after_call.contract_source_code == Map.get(valid_attrs, :contract_source_code)
    end

    test "check additional sources update", %{
      address: address,
      secondary_sources: secondary_sources,
      changed_sources: changed_sources
    } do
      sc_before_call =
        Repo.get_by(Address, hash: address.hash) |> Repo.preload(smart_contract: :smart_contract_additional_sources)

      assert sc_before_call.smart_contract.smart_contract_additional_sources
             |> Enum.with_index()
             |> Enum.all?(fn {el, ind} ->
               {:ok, src} = Enum.fetch(secondary_sources, ind)

               el.file_name == Map.get(src, :file_name) and
                 el.contract_source_code == Map.get(src, :contract_source_code)
             end)

      assert {:ok, %SmartContract{}} =
               SmartContract.update_smart_contract(%{address_hash: address.hash}, [], changed_sources)

      sc_after_call =
        Repo.get_by(Address, hash: address.hash) |> Repo.preload(smart_contract: :smart_contract_additional_sources)

      assert sc_after_call.smart_contract.smart_contract_additional_sources
             |> Enum.with_index()
             |> Enum.all?(fn {el, ind} ->
               {:ok, src} = Enum.fetch(changed_sources, ind)

               el.file_name == Map.get(src, :file_name) and
                 el.contract_source_code == Map.get(src, :contract_source_code)
             end)
    end
  end

  test "get_abi/1 returns empty [] abi if implementation address is null" do
    assert SmartContract.get_abi(nil) == []
  end

  test "get_abi/1 returns [] if implementation is not verified" do
    implementation_contract_address = insert(:contract_address)

    implementation_contract_address_hash_string =
      Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

    assert SmartContract.get_abi("0x" <> implementation_contract_address_hash_string) == []
  end

  @abi [
    %{
      "constant" => false,
      "inputs" => [%{"name" => "x", "type" => "uint256"}],
      "name" => "set",
      "outputs" => [],
      "payable" => false,
      "stateMutability" => "nonpayable",
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "get",
      "outputs" => [%{"name" => "", "type" => "uint256"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @proxy_abi [
    %{
      "type" => "function",
      "stateMutability" => "nonpayable",
      "payable" => false,
      "outputs" => [%{"type" => "bool", "name" => ""}],
      "name" => "upgradeTo",
      "inputs" => [%{"type" => "address", "name" => "newImplementation"}],
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
      "stateMutability" => "nonpayable",
      "payable" => false,
      "outputs" => [],
      "name" => "renounceOwnership",
      "inputs" => [],
      "constant" => false
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "address", "name" => ""}],
      "name" => "getOwner",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [%{"type" => "address", "name" => ""}],
      "name" => "getProxyStorage",
      "inputs" => [],
      "constant" => true
    },
    %{
      "type" => "function",
      "stateMutability" => "nonpayable",
      "payable" => false,
      "outputs" => [],
      "name" => "transferOwnership",
      "inputs" => [%{"type" => "address", "name" => "_newOwner"}],
      "constant" => false
    },
    %{
      "type" => "constructor",
      "stateMutability" => "nonpayable",
      "payable" => false,
      "inputs" => [
        %{"type" => "address", "name" => "_proxyStorage"},
        %{"type" => "address", "name" => "_implementationAddress"}
      ]
    },
    %{"type" => "fallback", "stateMutability" => "nonpayable", "payable" => false},
    %{
      "type" => "event",
      "name" => "Upgraded",
      "inputs" => [
        %{"type" => "uint256", "name" => "version", "indexed" => false},
        %{"type" => "address", "name" => "implementation", "indexed" => true}
      ],
      "anonymous" => false
    },
    %{
      "type" => "event",
      "name" => "OwnershipRenounced",
      "inputs" => [%{"type" => "address", "name" => "previousOwner", "indexed" => true}],
      "anonymous" => false
    },
    %{
      "type" => "event",
      "name" => "OwnershipTransferred",
      "inputs" => [
        %{"type" => "address", "name" => "previousOwner", "indexed" => true},
        %{"type" => "address", "name" => "newOwner", "indexed" => true}
      ],
      "anonymous" => false
    }
  ]

  test "get_abi/1 returns implementation abi if implementation is verified" do
    proxy_contract_address = insert(:contract_address)
    insert(:smart_contract, address_hash: proxy_contract_address.hash, abi: @proxy_abi, contract_code_md5: "123")

    implementation_contract_address = insert(:contract_address)

    insert(:smart_contract,
      address_hash: implementation_contract_address.hash,
      abi: @abi,
      contract_code_md5: "123"
    )

    implementation_contract_address_hash_string =
      Base.encode16(implementation_contract_address.hash.bytes, case: :lower)

    implementation_abi = SmartContract.get_abi("0x" <> implementation_contract_address_hash_string)

    assert implementation_abi == @abi
  end

  test "format_constructor_arguments/2 decodes tuple components without logging a warning" do
    tuple_input = %{
      "components" => [
        %{"name" => "twitter", "type" => "string"},
        %{"name" => "telegram", "type" => "string"},
        %{"name" => "discord", "type" => "string"},
        %{"name" => "website", "type" => "string"},
        %{"name" => "farcaster", "type" => "string"}
      ],
      "name" => "socials_",
      "type" => "tuple"
    }

    tuple_type = ABI.FunctionSelector.parse_specification_type(tuple_input)

    constructor_arguments =
      [{"", "", "", "", ""}]
      |> ABI.TypeEncoder.encode([tuple_type])
      |> Base.encode16(case: :lower)

    log =
      capture_log(fn ->
        assert SmartContract.format_constructor_arguments(
                 [%{"inputs" => [tuple_input], "type" => "constructor"}],
                 constructor_arguments
               ) == [[["", "", "", "", ""], tuple_input]]
      end)

    refute log =~ ~s(Error determining value json for "tuple")
  end
end
