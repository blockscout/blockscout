defmodule BlockScoutWeb.API.V2.SmartContractControllerTest do
  use BlockScoutWeb.ConnCase, async: false
  use BlockScoutWeb.ChannelCase, async: false

  import Mox

  alias BlockScoutWeb.AddressContractView
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Account.Identity
  alias Explorer.TestHelper
  alias Plug.Conn

  setup :set_mox_from_context

  setup :verify_on_exit!

  describe "/smart-contracts/{address_hash}" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/smart-contracts/#{address.hash}")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/0x")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get unverified smart-contract info", %{conn: conn} do
      address = insert(:contract_address)

      TestHelper.get_eip1967_implementation_error_response()

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      response = json_response(request, 200)

      assert response ==
               %{
                 "proxy_type" => nil,
                 "implementations" => [],
                 "has_custom_methods_read" => false,
                 "has_custom_methods_write" => false,
                 "is_self_destructed" => false,
                 "deployed_bytecode" => to_string(address.contract_code),
                 "creation_bytecode" => nil
               }

      insert(:transaction,
        created_contract_address_hash: address.hash,
        input:
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
      )
      |> with_block()

      TestHelper.get_eip1967_implementation_error_response()

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      response = json_response(request, 200)

      assert response ==
               %{
                 "proxy_type" => nil,
                 "implementations" => [],
                 "has_custom_methods_read" => false,
                 "has_custom_methods_write" => false,
                 "is_self_destructed" => false,
                 "deployed_bytecode" => to_string(address.contract_code),
                 "creation_bytecode" =>
                   "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
               }
    end

    test "get an eip1967 proxy contract", %{conn: conn} do
      implementation_address = insert(:contract_address)
      proxy_address = insert(:contract_address)

      _proxy_smart_contract =
        insert(:smart_contract,
          address_hash: proxy_address.hash,
          contract_code_md5: "123"
        )

      implementation =
        insert(:proxy_implementation,
          proxy_address_hash: proxy_address.hash,
          proxy_type: "eip1967",
          address_hashes: [implementation_address.hash],
          names: [nil]
        )

      assert implementation.proxy_type == :eip1967

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(proxy_address.hash)}")
      response = json_response(request, 200)

      assert response["has_methods_read_proxy"] == true
      assert response["has_methods_write_proxy"] == true
    end

    test "get smart-contract", %{conn: conn} do
      lib_address = build(:address)
      lib_address_string = to_string(lib_address)

      target_contract =
        insert(:smart_contract,
          external_libraries: [%{name: "ABC", address_hash: lib_address_string}],
          constructor_arguments:
            "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000002cf6e7c9ec35d0b08a1062e13854f74b1aaae54e"
        )

      insert(:transaction,
        created_contract_address_hash: target_contract.address_hash,
        input:
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
      )
      |> with_block()

      implementation_address = insert(:address)
      implementation_address_hash_string = to_string(implementation_address.hash)
      formatted_implementation_address_hash_string = to_string(Address.checksum(implementation_address.hash))

      correct_response = %{
        "verified_twin_address_hash" => nil,
        "is_verified" => true,
        "is_changed_bytecode" => false,
        "is_partially_verified" => target_contract.partially_verified,
        "is_fully_verified" => true,
        "is_verified_via_sourcify" => target_contract.verified_via_sourcify,
        "is_vyper_contract" => target_contract.is_vyper_contract,
        "has_methods_read" => true,
        "has_methods_write" => true,
        "has_methods_read_proxy" => true,
        "has_methods_write_proxy" => true,
        "has_custom_methods_read" => false,
        "has_custom_methods_write" => false,
        "minimal_proxy_address_hash" => nil,
        "sourcify_repo_url" =>
          if(target_contract.verified_via_sourcify,
            do: AddressContractView.sourcify_repo_url(target_contract.address_hash, target_contract.partially_verified)
          ),
        "can_be_visualized_via_sol2uml" => false,
        "name" => target_contract && target_contract.name,
        "compiler_version" => target_contract.compiler_version,
        "optimization_enabled" => target_contract.optimization,
        "optimization_runs" => target_contract.optimization_runs,
        "evm_version" => target_contract.evm_version,
        "verified_at" => target_contract.inserted_at |> to_string() |> String.replace(" ", "T"),
        "source_code" => target_contract.contract_source_code,
        "file_path" => target_contract.file_path,
        "additional_sources" => [],
        "compiler_settings" => target_contract.compiler_settings,
        "external_libraries" => [%{"name" => "ABC", "address_hash" => Address.checksum(lib_address)}],
        "constructor_args" => target_contract.constructor_arguments,
        "decoded_constructor_args" => nil,
        "is_self_destructed" => false,
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi,
        "proxy_type" => "eip1967",
        "implementations" => [%{"address" => formatted_implementation_address_hash_string, "name" => nil}],
        "is_verified_via_eth_bytecode_db" => target_contract.verified_via_eth_bytecode_db,
        "is_verified_via_verifier_alliance" => target_contract.verified_via_verifier_alliance,
        "language" => smart_contract_language(target_contract),
        "license_type" => "none",
        "certified" => false,
        "is_blueprint" => false
      }

      TestHelper.get_eip1967_implementation_non_zero_address(implementation_address_hash_string)

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(target_contract.address_hash)}")
      response = json_response(request, 200)

      result_props = correct_response |> Map.keys()

      for prop <- result_props do
        assert prepare_implementation(correct_response[prop]) == response[prop]
      end
    end

    test "get smart-contract with decoded constructor", %{conn: conn} do
      lib_address = build(:address)
      lib_address_string = to_string(lib_address)

      target_contract =
        insert(:smart_contract,
          external_libraries: [%{name: "ABC", address_hash: lib_address_string}],
          constructor_arguments:
            "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000002cf6e7c9ec35d0b08a1062e13854f74b1aaae54e",
          abi: [
            %{
              "type" => "constructor",
              "inputs" => [
                %{"type" => "address", "name" => "_proxyStorage"},
                %{"type" => "address", "name" => "_implementationAddress"}
              ]
            },
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
          license_type: 13
        )

      insert(:transaction,
        created_contract_address_hash: target_contract.address_hash,
        input:
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
      )
      |> with_block()

      correct_response = %{
        "verified_twin_address_hash" => nil,
        "is_verified" => true,
        "is_changed_bytecode" => false,
        "is_partially_verified" => target_contract.partially_verified,
        "is_fully_verified" => true,
        "is_verified_via_sourcify" => target_contract.verified_via_sourcify,
        "is_vyper_contract" => target_contract.is_vyper_contract,
        "has_methods_read" => true,
        "has_methods_read_proxy" => false,
        "has_methods_write" => true,
        "has_methods_write_proxy" => false,
        "has_custom_methods_read" => false,
        "has_custom_methods_write" => false,
        "minimal_proxy_address_hash" => nil,
        "sourcify_repo_url" =>
          if(target_contract.verified_via_sourcify,
            do: AddressContractView.sourcify_repo_url(target_contract.address_hash, target_contract.partially_verified)
          ),
        "can_be_visualized_via_sol2uml" => false,
        "name" => target_contract && target_contract.name,
        "compiler_version" => target_contract.compiler_version,
        "optimization_enabled" => target_contract.optimization,
        "optimization_runs" => target_contract.optimization_runs,
        "evm_version" => target_contract.evm_version,
        "verified_at" => target_contract.inserted_at |> to_string() |> String.replace(" ", "T"),
        "source_code" => target_contract.contract_source_code,
        "file_path" => target_contract.file_path,
        "additional_sources" => [],
        "compiler_settings" => target_contract.compiler_settings,
        "external_libraries" => [%{"name" => "ABC", "address_hash" => Address.checksum(lib_address)}],
        "constructor_args" => target_contract.constructor_arguments,
        "decoded_constructor_args" => [
          ["0x0000000000000000000000000000000000000000", %{"name" => "_proxyStorage", "type" => "address"}],
          [
            Address.checksum("0x2Cf6E7c9eC35D0B08A1062e13854f74b1aaae54e"),
            %{"name" => "_implementationAddress", "type" => "address"}
          ]
        ],
        "is_self_destructed" => false,
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi,
        "proxy_type" => nil,
        "implementations" => [],
        "is_verified_via_eth_bytecode_db" => target_contract.verified_via_eth_bytecode_db,
        "is_verified_via_verifier_alliance" => target_contract.verified_via_verifier_alliance,
        "language" => smart_contract_language(target_contract),
        "license_type" => "gnu_agpl_v3",
        "certified" => false,
        "is_blueprint" => false
      }

      TestHelper.get_eip1967_implementation_error_response()

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(target_contract.address_hash)}")
      response = json_response(request, 200)

      result_props = correct_response |> Map.keys()

      for prop <- result_props do
        assert correct_response[prop] == response[prop]
      end
    end

    test "get smart-contract data from bytecode twin without constructor args", %{conn: conn} do
      lib_address = build(:address)
      lib_address_string = to_string(lib_address)

      target_contract =
        insert(:smart_contract,
          external_libraries: [%{name: "ABC", address_hash: lib_address_string}],
          constructor_arguments:
            "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000002cf6e7c9ec35d0b08a1062e13854f74b1aaae54e",
          abi: [
            %{
              "type" => "constructor",
              "inputs" => [
                %{"type" => "address", "name" => "_proxyStorage"},
                %{"type" => "address", "name" => "_implementationAddress"}
              ]
            },
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
        )

      insert(:transaction,
        created_contract_address_hash: target_contract.address_hash,
        input:
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
      )
      |> with_block(status: :ok)

      address = insert(:contract_address)

      insert(:transaction,
        created_contract_address_hash: address.hash,
        input:
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
      )
      |> with_block(status: :ok)

      correct_response = %{
        "verified_twin_address_hash" => Address.checksum(target_contract.address_hash),
        "is_verified" => false,
        "is_changed_bytecode" => false,
        "is_partially_verified" => target_contract.partially_verified,
        "is_fully_verified" => false,
        "is_verified_via_sourcify" => false,
        "is_vyper_contract" => target_contract.is_vyper_contract,
        "has_methods_read" => true,
        "has_methods_write" => true,
        "has_methods_read_proxy" => false,
        "has_methods_write_proxy" => false,
        "has_custom_methods_read" => false,
        "has_custom_methods_write" => false,
        "minimal_proxy_address_hash" => nil,
        "sourcify_repo_url" => nil,
        "can_be_visualized_via_sol2uml" => false,
        "name" => target_contract && target_contract.name,
        "compiler_version" => target_contract.compiler_version,
        "optimization_enabled" => target_contract.optimization,
        "optimization_runs" => target_contract.optimization_runs,
        "evm_version" => target_contract.evm_version,
        "verified_at" => target_contract.inserted_at |> to_string() |> String.replace(" ", "T"),
        "source_code" => target_contract.contract_source_code,
        "file_path" => target_contract.file_path,
        "additional_sources" => [],
        "compiler_settings" => target_contract.compiler_settings,
        "external_libraries" => [%{"name" => "ABC", "address_hash" => Address.checksum(lib_address)}],
        "constructor_args" => nil,
        "decoded_constructor_args" => nil,
        "is_self_destructed" => false,
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi,
        "proxy_type" => nil,
        "implementations" => [],
        "is_verified_via_eth_bytecode_db" => target_contract.verified_via_eth_bytecode_db,
        "is_verified_via_verifier_alliance" => target_contract.verified_via_verifier_alliance,
        "language" => smart_contract_language(target_contract),
        "license_type" => "none",
        "certified" => false,
        "is_blueprint" => false
      }

      TestHelper.get_eip1967_implementation_zero_addresses()

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      response = json_response(request, 200)

      result_props = correct_response |> Map.keys()

      for prop <- result_props do
        assert correct_response[prop] == response[prop]
      end
    end

    test "doesn't get smart-contract multiple additional sources from EIP-1167 implementation", %{conn: conn} do
      implementation_contract =
        insert(:smart_contract,
          external_libraries: [],
          constructor_arguments: "",
          abi: [
            %{
              "type" => "constructor",
              "inputs" => [
                %{"type" => "address", "name" => "_proxyStorage"},
                %{"type" => "address", "name" => "_implementationAddress"}
              ]
            },
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
          license_type: 9
        )

      insert(:smart_contract_additional_source,
        file_name: "test1",
        contract_source_code: "test2",
        address_hash: implementation_contract.address_hash
      )

      insert(:smart_contract_additional_source,
        file_name: "test3",
        contract_source_code: "test4",
        address_hash: implementation_contract.address_hash
      )

      implementation_contract_address_hash_string =
        Base.encode16(implementation_contract.address_hash.bytes, case: :lower)

      proxy_transaction_input =
        "0x11b804ab000000000000000000000000" <>
          implementation_contract_address_hash_string <>
          "000000000000000000000000000000000000000000000000000000000000006035323031313537360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000284e159163400000000000000000000000034420c13696f4ac650b9fafe915553a1abcd7dd30000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000ff5ae9b0a7522736299d797d80b8fc6f31d61100000000000000000000000000ff5ae9b0a7522736299d797d80b8fc6f31d6110000000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034420c13696f4ac650b9fafe915553a1abcd7dd300000000000000000000000000000000000000000000000000000000000000184f7074696d69736d2053756273637269626572204e465473000000000000000000000000000000000000000000000000000000000000000000000000000000054f504e46540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000037697066733a2f2f516d66544e504839765651334b5952346d6b52325a6b757756424266456f5a5554545064395538666931503332752f300000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000c82bbe41f2cf04e3a8efa18f7032bdd7f6d98a81000000000000000000000000efba8a2a82ec1fb1273806174f5e28fbb917cf9500000000000000000000000000000000000000000000000000000000"

      proxy_deployed_bytecode =
        "0x363d3d373d3d3d363d73" <> implementation_contract_address_hash_string <> "5af43d82803e903d91602b57fd5bf3"

      proxy_address =
        insert(:contract_address,
          contract_code: proxy_deployed_bytecode
        )

      insert(:transaction,
        created_contract_address_hash: proxy_address.hash,
        input: proxy_transaction_input
      )
      |> with_block(status: :ok)

      correct_response = %{
        "has_custom_methods_read" => false,
        "has_custom_methods_write" => false,
        "is_self_destructed" => false,
        "deployed_bytecode" => proxy_deployed_bytecode,
        "creation_bytecode" => proxy_transaction_input,
        "proxy_type" => "eip1167",
        "implementations" => [
          %{
            "address" => Address.checksum(implementation_contract.address_hash),
            "name" => implementation_contract.name
          }
        ]
      }

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(proxy_address.hash)}")
      response = json_response(request, 200)

      result_props = correct_response |> Map.keys()

      for prop <- result_props do
        assert prepare_implementation(correct_response[prop]) == response[prop]
      end
    end

    test "get smart-contract which is blueprint", %{conn: conn} do
      target_contract =
        insert(:smart_contract,
          is_blueprint: true
        )

      insert(:transaction,
        created_contract_address_hash: target_contract.address_hash,
        input:
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
      )
      |> with_block()

      correct_response = %{
        "verified_twin_address_hash" => nil,
        "is_verified" => true,
        "is_changed_bytecode" => false,
        "is_partially_verified" => target_contract.partially_verified,
        "is_fully_verified" => true,
        "is_verified_via_sourcify" => target_contract.verified_via_sourcify,
        "is_vyper_contract" => target_contract.is_vyper_contract,
        "has_methods_read" => true,
        "has_methods_write" => true,
        "has_methods_read_proxy" => false,
        "has_methods_write_proxy" => false,
        "has_custom_methods_read" => false,
        "has_custom_methods_write" => false,
        "minimal_proxy_address_hash" => nil,
        "sourcify_repo_url" =>
          if(target_contract.verified_via_sourcify,
            do: AddressContractView.sourcify_repo_url(target_contract.address_hash, target_contract.partially_verified)
          ),
        "can_be_visualized_via_sol2uml" => false,
        "name" => target_contract && target_contract.name,
        "compiler_version" => target_contract.compiler_version,
        "optimization_enabled" => target_contract.optimization,
        "optimization_runs" => target_contract.optimization_runs,
        "evm_version" => target_contract.evm_version,
        "verified_at" => target_contract.inserted_at |> to_string() |> String.replace(" ", "T"),
        "source_code" => target_contract.contract_source_code,
        "file_path" => target_contract.file_path,
        "additional_sources" => [],
        "compiler_settings" => target_contract.compiler_settings,
        "external_libraries" => target_contract.external_libraries,
        "constructor_args" => target_contract.constructor_arguments,
        "decoded_constructor_args" => nil,
        "is_self_destructed" => false,
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi,
        "proxy_type" => nil,
        "implementations" => [],
        "is_verified_via_eth_bytecode_db" => target_contract.verified_via_eth_bytecode_db,
        "is_verified_via_verifier_alliance" => target_contract.verified_via_verifier_alliance,
        "language" => smart_contract_language(target_contract),
        "license_type" => "none",
        "certified" => false,
        "is_blueprint" => true
      }

      TestHelper.get_eip1967_implementation_zero_addresses()

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(target_contract.address_hash)}")
      response = json_response(request, 200)

      result_props = correct_response |> Map.keys()

      for prop <- result_props do
        assert correct_response[prop] == response[prop]
      end
    end
  end

  test "doesn't get smart-contract implementation for 'Clones with immutable arguments' pattern", %{conn: conn} do
    implementation_contract =
      insert(:smart_contract,
        external_libraries: [],
        constructor_arguments: "",
        abi: [
          %{
            "type" => "constructor",
            "inputs" => [
              %{"type" => "address", "name" => "_proxyStorage"},
              %{"type" => "address", "name" => "_implementationAddress"}
            ]
          },
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
        license_type: 9
      )

    insert(:smart_contract_additional_source,
      file_name: "test1",
      contract_source_code: "test2",
      address_hash: implementation_contract.address_hash
    )

    implementation_contract_address_hash_string =
      Base.encode16(implementation_contract.address_hash.bytes, case: :lower)

    proxy_transaction_input =
      "0x684fbe55000000000000000000000000af1caf51d49b0e63d1ff7e5d4ed6ea26d15f3f9d000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"

    proxy_deployed_bytecode =
      "0x3d3d3d3d363d3d3761003f603736393661003f013d73" <>
        implementation_contract_address_hash_string <>
        "5af43d3d93803e603557fd5bf3af1caf51d49b0e63d1ff7e5d4ed6ea26d15f3f9d0000000000000000000000000000000000000000000000000000000000000001000000000000000203003d"

    proxy_address =
      insert(:contract_address,
        contract_code: proxy_deployed_bytecode
      )

    insert(:transaction,
      created_contract_address_hash: proxy_address.hash,
      input: proxy_transaction_input
    )
    |> with_block(status: :ok)

    formatted_implementation_address_hash_string = to_string(Address.checksum(implementation_contract.address_hash))

    correct_response = %{
      "proxy_type" => "clone_with_immutable_arguments",
      "implementations" => [
        %{"address" => formatted_implementation_address_hash_string, "name" => implementation_contract.name}
      ],
      "has_custom_methods_read" => false,
      "has_custom_methods_write" => false,
      "is_self_destructed" => false,
      "deployed_bytecode" => proxy_deployed_bytecode,
      "creation_bytecode" => proxy_transaction_input
    }

    request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(proxy_address.hash)}")
    response = json_response(request, 200)

    result_props = correct_response |> Map.keys()

    for prop <- result_props do
      assert prepare_implementation(correct_response[prop]) == response[prop]
    end
  end

  if Application.compile_env(:explorer, :chain_type) !== :zksync do
    describe "/smart-contracts/{address_hash} <> eth_bytecode_db" do
      setup do
        old_interval_env = Application.get_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand)

        :ok

        on_exit(fn ->
          Application.put_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand, old_interval_env)
        end)
      end

      test "automatically verify contract", %{conn: conn} do
        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        Application.put_env(:block_scout_web, :chain_id, 5)

        bypass = Bypass.open()
        eth_bytecode_response = File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_response.json")

        old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)

        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          service_url: "http://localhost:#{bypass.port}",
          enabled: true,
          type: "eth_bytecode_db",
          eth_bytecode_db?: true
        )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.UserSocketV2
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search_all", fn conn ->
          Conn.resp(conn, 200, eth_bytecode_response)
        end)

        TestHelper.get_eip1967_implementation_error_response()

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        response = json_response(request, 200)

        assert response ==
                 %{
                   "proxy_type" => nil,
                   "implementations" => [],
                   "has_custom_methods_read" => false,
                   "has_custom_methods_write" => false,
                   "is_self_destructed" => false,
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
                 }

        TestHelper.get_eip1967_implementation_zero_addresses()

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_partially_verified" => true} = response
        assert %{"is_fully_verified" => false} = response

        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_env)
        Bypass.down(bypass)
        GenServer.stop(pid)
      end

      test "automatically verify contract using search-all (ethBytecodeDbSources) endpoint", %{conn: conn} do
        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        Application.put_env(:block_scout_web, :chain_id, 5)

        bypass = Bypass.open()

        eth_bytecode_response =
          File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_all_local_sources_response.json")

        old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)

        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          service_url: "http://localhost:#{bypass.port}",
          enabled: true,
          type: "eth_bytecode_db",
          eth_bytecode_db?: true
        )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.UserSocketV2
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search_all", fn conn ->
          Conn.resp(conn, 200, eth_bytecode_response)
        end)

        TestHelper.get_eip1967_implementation_error_response()

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        response = json_response(request, 200)

        assert response ==
                 %{
                   "proxy_type" => nil,
                   "implementations" => [],
                   "has_custom_methods_read" => false,
                   "has_custom_methods_write" => false,
                   "is_self_destructed" => false,
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
                 }

        TestHelper.get_eip1967_implementation_zero_addresses()

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_partially_verified" => true} = response
        assert %{"is_fully_verified" => false} = response

        smart_contract = Jason.decode!(eth_bytecode_response)["ethBytecodeDbSources"] |> List.first()
        assert response["compiler_settings"] == Jason.decode!(smart_contract["compilerSettings"])
        assert response["name"] == smart_contract["contractName"]
        assert response["compiler_version"] == smart_contract["compilerVersion"]
        assert response["file_path"] == smart_contract["fileName"]
        assert response["constructor_args"] == smart_contract["constructorArguments"]
        assert response["abi"] == Jason.decode!(smart_contract["abi"])

        assert response["decoded_constructor_args"] == [
                 [
                   Address.checksum("0xc35DADB65012eC5796536bD9864eD8773aBc74C4"),
                   %{
                     "internalType" => "address",
                     "name" => "_factory",
                     "type" => "address"
                   }
                 ],
                 [
                   Address.checksum("0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"),
                   %{
                     "internalType" => "address",
                     "name" => "_WETH",
                     "type" => "address"
                   }
                 ]
               ]

        assert response["source_code"] == smart_contract["sourceFiles"][smart_contract["fileName"]]

        assert response["external_libraries"] == [
                 %{
                   "address_hash" => Address.checksum("0x00000000D41867734BBee4C6863D9255b2b06aC1"),
                   "name" => "__CACHE_BREAKER__"
                 }
               ]

        additional_sources =
          for file_name <- Map.keys(smart_contract["sourceFiles"]), smart_contract["fileName"] != file_name do
            %{
              "source_code" => smart_contract["sourceFiles"][file_name],
              "file_path" => file_name
            }
          end

        assert response["additional_sources"] |> Enum.sort_by(fn x -> x["file_path"] end) ==
                 additional_sources |> Enum.sort_by(fn x -> x["file_path"] end)

        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_env)
        Bypass.down(bypass)
        GenServer.stop(pid)
      end

      test "automatically verify contract using search-all (sourcifySources) endpoint", %{conn: conn} do
        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        Application.put_env(:block_scout_web, :chain_id, 5)

        bypass = Bypass.open()

        eth_bytecode_response =
          File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_all_sourcify_sources_response.json")

        old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)

        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          service_url: "http://localhost:#{bypass.port}",
          enabled: true,
          type: "eth_bytecode_db",
          eth_bytecode_db?: true
        )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.UserSocketV2
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search_all", fn conn ->
          Conn.resp(conn, 200, eth_bytecode_response)
        end)

        TestHelper.get_eip1967_implementation_zero_addresses()

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        response = json_response(request, 200)

        assert response ==
                 %{
                   "proxy_type" => "unknown",
                   "implementations" => [],
                   "has_custom_methods_read" => false,
                   "has_custom_methods_write" => false,
                   "is_self_destructed" => false,
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
                 }

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_verified_via_sourcify" => true} = response
        assert %{"is_partially_verified" => true} = response
        assert %{"is_fully_verified" => false} = response
        assert response["file_path"] == "Test.sol"

        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_env)
        Bypass.down(bypass)
        GenServer.stop(pid)
      end

      test "automatically verify contract using search-all (sourcifySources with libraries) endpoint", %{conn: conn} do
        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        Application.put_env(:block_scout_web, :chain_id, 5)

        bypass = Bypass.open()

        eth_bytecode_response =
          File.read!(
            "./test/support/fixture/smart_contract/eth_bytecode_db_search_all_sourcify_sources_with_libs_response.json"
          )

        old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)

        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          service_url: "http://localhost:#{bypass.port}",
          enabled: true,
          type: "eth_bytecode_db",
          eth_bytecode_db?: true
        )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.UserSocketV2
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search_all", fn conn ->
          Conn.resp(conn, 200, eth_bytecode_response)
        end)

        TestHelper.get_eip1967_implementation_error_response()

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        response = json_response(request, 200)

        assert response ==
                 %{
                   "proxy_type" => nil,
                   "implementations" => [],
                   "has_custom_methods_read" => false,
                   "has_custom_methods_write" => false,
                   "is_self_destructed" => false,
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
                 }

        TestHelper.get_eip1967_implementation_zero_addresses()

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)

        smart_contract = Jason.decode!(eth_bytecode_response)["sourcifySources"] |> List.first()
        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_verified_via_sourcify" => true} = response
        assert %{"is_partially_verified" => true} = response
        assert %{"is_fully_verified" => false} = response
        assert response["file_path"] == "src/zkbob/ZkBobPool.sol"

        assert response["external_libraries"] == [
                 %{
                   "address_hash" => Address.checksum("0x22DE6B06544Ee5Cd907813a04bcdEd149A2f49D2"),
                   "name" => "lib/base58-solidity/contracts/Base58.sol:Base58"
                 },
                 %{
                   "address_hash" => Address.checksum("0x019d3788F00a7087234f3844CB1ceCe1F9982B7A"),
                   "name" => "src/libraries/ZkAddress.sol:ZkAddress"
                 }
               ]

        additional_sources =
          for file_name <- Map.keys(smart_contract["sourceFiles"]), smart_contract["fileName"] != file_name do
            %{
              "source_code" => smart_contract["sourceFiles"][file_name],
              "file_path" => file_name
            }
          end

        assert response["additional_sources"] |> Enum.sort_by(fn x -> x["file_path"] end) ==
                 additional_sources |> Enum.sort_by(fn x -> x["file_path"] end)

        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_env)
        Bypass.down(bypass)
        GenServer.stop(pid)
      end

      test "automatically verify contract using search-all (allianceSources) endpoint", %{conn: conn} do
        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        Application.put_env(:block_scout_web, :chain_id, 5)

        bypass = Bypass.open()

        eth_bytecode_response =
          File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_all_alliance_sources_response.json")

        old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)

        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          service_url: "http://localhost:#{bypass.port}",
          enabled: true,
          type: "eth_bytecode_db",
          eth_bytecode_db?: true
        )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.UserSocketV2
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search_all", fn conn ->
          Conn.resp(conn, 200, eth_bytecode_response)
        end)

        implementation_address = insert(:address)
        implementation_address_hash_string = to_string(implementation_address.hash)
        formatted_implementation_address_hash_string = to_string(Address.checksum(implementation_address.hash))
        TestHelper.get_eip1967_implementation_non_zero_address(implementation_address_hash_string)

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        response = json_response(request, 200)

        assert response ==
                 %{
                   "proxy_type" => "eip1967",
                   "implementations" => [
                     prepare_implementation(%{"address" => formatted_implementation_address_hash_string, "name" => nil})
                   ],
                   "has_custom_methods_read" => false,
                   "has_custom_methods_write" => false,
                   "is_self_destructed" => false,
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
                 }

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"proxy_type" => "eip1967"} = response

        assert %{"implementations" => [%{"address" => ^formatted_implementation_address_hash_string, "name" => nil}]} =
                 response

        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_partially_verified" => true} = response
        assert %{"is_verified_via_sourcify" => false} = response
        assert %{"is_verified_via_verifier_alliance" => true} = response
        assert %{"is_fully_verified" => false} = response

        smart_contract = Jason.decode!(eth_bytecode_response)["allianceSources"] |> List.first()
        assert response["compiler_settings"] == Jason.decode!(smart_contract["compilerSettings"])
        assert response["name"] == smart_contract["contractName"]
        assert response["compiler_version"] == smart_contract["compilerVersion"]
        assert response["file_path"] == smart_contract["fileName"]
        assert response["constructor_args"] == smart_contract["constructorArguments"]
        assert response["abi"] == Jason.decode!(smart_contract["abi"])

        assert response["source_code"] == smart_contract["sourceFiles"][smart_contract["fileName"]]

        assert response["external_libraries"] == [
                 %{
                   "address_hash" => Address.checksum("0x00000000D41867734BBee4C6863D9255b2b06aC1"),
                   "name" => "__CACHE_BREAKER__"
                 }
               ]

        additional_sources =
          for file_name <- Map.keys(smart_contract["sourceFiles"]), smart_contract["fileName"] != file_name do
            %{
              "source_code" => smart_contract["sourceFiles"][file_name],
              "file_path" => file_name
            }
          end

        assert response["additional_sources"] |> Enum.sort_by(fn x -> x["file_path"] end) ==
                 additional_sources |> Enum.sort_by(fn x -> x["file_path"] end)

        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_env)
        Bypass.down(bypass)
        GenServer.stop(pid)
      end

      test "automatically verify contract using search-all (prefer sourcify FULL match) endpoint", %{conn: conn} do
        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        Application.put_env(:block_scout_web, :chain_id, 5)

        bypass = Bypass.open()

        eth_bytecode_response =
          File.read!(
            "./test/support/fixture/smart_contract/eth_bytecode_db_search_all_alliance_sources_partial_response.json"
          )

        old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)

        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          service_url: "http://localhost:#{bypass.port}",
          enabled: true,
          type: "eth_bytecode_db",
          eth_bytecode_db?: true
        )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.UserSocketV2
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search_all", fn conn ->
          Conn.resp(conn, 200, eth_bytecode_response)
        end)

        implementation_address = insert(:address)
        implementation_address_hash_string = to_string(implementation_address.hash)
        formatted_implementation_address_hash_string = to_string(Address.checksum(implementation_address.hash))
        TestHelper.get_eip1967_implementation_non_zero_address(implementation_address_hash_string)

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        response = json_response(request, 200)

        assert response ==
                 %{
                   "proxy_type" => "eip1967",
                   "implementations" => [
                     prepare_implementation(%{"address" => formatted_implementation_address_hash_string, "name" => nil})
                   ],
                   "has_custom_methods_read" => false,
                   "has_custom_methods_write" => false,
                   "is_self_destructed" => false,
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
                 }

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"proxy_type" => "eip1967"} = response

        assert %{"implementations" => [%{"address" => ^formatted_implementation_address_hash_string, "name" => nil}]} =
                 response

        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_partially_verified" => false} = response
        assert %{"is_verified_via_sourcify" => true} = response
        assert %{"is_verified_via_verifier_alliance" => false} = response
        assert %{"is_fully_verified" => true} = response

        smart_contract = Jason.decode!(eth_bytecode_response)["sourcifySources"] |> List.first()
        assert response["compiler_settings"] == Jason.decode!(smart_contract["compilerSettings"])
        assert response["name"] == smart_contract["contractName"]
        assert response["compiler_version"] == smart_contract["compilerVersion"]
        assert response["file_path"] == smart_contract["fileName"]
        assert response["constructor_args"] == smart_contract["constructorArguments"]
        assert response["abi"] == Jason.decode!(smart_contract["abi"])

        assert response["source_code"] == smart_contract["sourceFiles"][smart_contract["fileName"]]

        assert response["external_libraries"] == [
                 %{
                   "address_hash" => Address.checksum("0x00000000D41867734BBee4C6863D9255b2b06aC1"),
                   "name" => "__CACHE_BREAKER__"
                 }
               ]

        additional_sources =
          for file_name <- Map.keys(smart_contract["sourceFiles"]), smart_contract["fileName"] != file_name do
            %{
              "source_code" => smart_contract["sourceFiles"][file_name],
              "file_path" => file_name
            }
          end

        assert response["additional_sources"] |> Enum.sort_by(fn x -> x["file_path"] end) ==
                 additional_sources |> Enum.sort_by(fn x -> x["file_path"] end)

        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_env)
        Bypass.down(bypass)
        GenServer.stop(pid)
      end

      test "automatically verify contract using search-all (take eth bytecode db FULL match) endpoint", %{conn: conn} do
        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        Application.put_env(:block_scout_web, :chain_id, 5)

        bypass = Bypass.open()

        eth_bytecode_response =
          File.read!(
            "./test/support/fixture/smart_contract/eth_bytecode_db_search_all_alliance_sources_partial_response_eth_bdb_full.json"
          )

        old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)

        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          service_url: "http://localhost:#{bypass.port}",
          enabled: true,
          type: "eth_bytecode_db",
          eth_bytecode_db?: true
        )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.UserSocketV2
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search_all", fn conn ->
          Conn.resp(conn, 200, eth_bytecode_response)
        end)

        implementation_address = insert(:address)
        implementation_address_hash_string = to_string(implementation_address.hash)
        formatted_implementation_address_hash_string = to_string(Address.checksum(implementation_address.hash))
        TestHelper.get_eip1967_implementation_non_zero_address(implementation_address_hash_string)

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        response = json_response(request, 200)

        assert response ==
                 %{
                   "proxy_type" => "eip1967",
                   "implementations" => [
                     prepare_implementation(%{"address" => formatted_implementation_address_hash_string, "name" => nil})
                   ],
                   "has_custom_methods_read" => false,
                   "has_custom_methods_write" => false,
                   "is_self_destructed" => false,
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
                 }

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"proxy_type" => "eip1967"} = response

        assert %{"implementations" => [%{"address" => ^formatted_implementation_address_hash_string, "name" => nil}]} =
                 response

        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_partially_verified" => false} = response
        assert %{"is_verified_via_sourcify" => false} = response
        assert %{"is_verified_via_verifier_alliance" => false} = response
        assert %{"is_fully_verified" => true} = response

        smart_contract = Jason.decode!(eth_bytecode_response)["ethBytecodeDbSources"] |> List.first()
        assert response["compiler_settings"] == Jason.decode!(smart_contract["compilerSettings"])
        assert response["name"] == smart_contract["contractName"]
        assert response["compiler_version"] == smart_contract["compilerVersion"]
        assert response["file_path"] == smart_contract["fileName"]
        assert response["constructor_args"] == smart_contract["constructorArguments"]
        assert response["abi"] == Jason.decode!(smart_contract["abi"])

        assert response["source_code"] == smart_contract["sourceFiles"][smart_contract["fileName"]]

        assert response["external_libraries"] == [
                 %{
                   "address_hash" => Address.checksum("0x00000000D41867734BBee4C6863D9255b2b06aC1"),
                   "name" => "__CACHE_BREAKER__"
                 }
               ]

        additional_sources =
          for file_name <- Map.keys(smart_contract["sourceFiles"]), smart_contract["fileName"] != file_name do
            %{
              "source_code" => smart_contract["sourceFiles"][file_name],
              "file_path" => file_name
            }
          end

        assert response["additional_sources"] |> Enum.sort_by(fn x -> x["file_path"] end) ==
                 additional_sources |> Enum.sort_by(fn x -> x["file_path"] end)

        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_env)
        Bypass.down(bypass)
        GenServer.stop(pid)
      end

      test "check fetch interval for LookUpSmartContractSourcesOnDemand and use sources:search endpoint since chain_id is unset",
           %{conn: conn} do
        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        Application.put_env(:block_scout_web, :chain_id, nil)

        bypass = Bypass.open()
        address = insert(:contract_address)
        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.UserSocketV2
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block()

        old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)

        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          service_url: "http://localhost:#{bypass.port}",
          enabled: true,
          type: "eth_bytecode_db",
          eth_bytecode_db?: true
        )

        old_interval_env = Application.get_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand)

        Application.put_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand, fetch_interval: 0)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search", fn conn ->
          Conn.resp(conn, 200, "{\"sources\": []}")
        end)

        TestHelper.get_eip1967_implementation_zero_addresses()

        _request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_not_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        :timer.sleep(10)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search", fn conn ->
          Conn.resp(conn, 200, "{\"sources\": []}")
        end)

        _request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_not_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        :timer.sleep(10)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search", fn conn ->
          Conn.resp(conn, 200, "{\"sources\": []}")
        end)

        _request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        assert_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_not_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        :timer.sleep(10)

        Application.put_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand, fetch_interval: 10000)

        _request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

        refute_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "eth_bytecode_db_lookup_started",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        refute_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_not_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        refute_receive %Phoenix.Socket.Message{
                         payload: %{},
                         event: "smart_contract_was_verified",
                         topic: ^topic
                       },
                       :timer.seconds(1)

        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand, old_interval_env)
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_env)
        Bypass.down(bypass)
        GenServer.stop(pid)
      end
    end
  end

  describe "/smart-contracts/{address_hash}/methods-read" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/smart-contracts/#{address.hash}/methods-read")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/0x/methods-read")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "return 404 on unverified contract", %{conn: conn} do
      address = insert(:contract_address)

      TestHelper.get_eip1967_implementation_zero_addresses()
      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}/methods-read")
      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get read-methods", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        },
        %{"type" => "fallback"},
        %{"type" => "receive"},
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [
            %{
              "type" => "tuple",
              "name" => "",
              "internalType" => "struct Storage.TransactionReceipt",
              "components" => [
                %{"type" => "bytes32", "name" => "txHash", "internalType" => "bytes32"},
                %{"type" => "uint256", "name" => "blockNumber", "internalType" => "uint256"},
                %{"type" => "bytes32", "name" => "blockHash", "internalType" => "bytes32"},
                %{"type" => "uint256", "name" => "transactionIndex", "internalType" => "uint256"},
                %{"type" => "address", "name" => "from", "internalType" => "address"},
                %{"type" => "address", "name" => "to", "internalType" => "address"},
                %{"type" => "uint256", "name" => "gasUsed", "internalType" => "uint256"},
                %{"type" => "bool", "name" => "status", "internalType" => "bool"},
                %{
                  "type" => "tuple[]",
                  "name" => "logs",
                  "internalType" => "struct Storage.Log[]",
                  "components" => [
                    %{"type" => "address", "name" => "from", "internalType" => "address"},
                    %{"type" => "bytes32[]", "name" => "topics", "internalType" => "bytes32[]"},
                    %{"type" => "bytes", "name" => "data", "internalType" => "bytes"}
                  ]
                }
              ]
            }
          ],
          "name" => "retrieve",
          "inputs" => []
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      address_hash = to_string(target_contract.address_hash)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id_1,
               method: "eth_call",
               params: [%{to: ^address_hash, from: "0xBb36c792B9B45Aaf8b848A1392B0d6559202729E", data: "0x2e64cec1"}, _]
             },
             %{
               id: id_2,
               method: "eth_call",
               params: [%{to: ^address_hash, from: "0xBb36c792B9B45Aaf8b848A1392B0d6559202729E", data: "0xab470f05"}, _]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id_2,
               jsonrpc: "2.0",
               result: "0x000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"
             },
             %{
               id: id_1,
               jsonrpc: "2.0",
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020fe6a43fa23a0269092cbf97cb908e1d5a49a18fd6942baf2467fb5b221e39ab200000000000000000000000000000000000000000000000000000000000003e8fe6a43fa23a0269092cbf97cb908e1d5a49a18fd6942baf2467fb5b221e39ab2000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000001e0f30000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000003307830000000000000000000000000000000000000000000000000000000000030783030313132323333000000000000000000000000000000000000000000003078303031313232333331323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3078303030303132333132330000000000000000000000000000000000000000000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000003307830000000000000000000000000000000000000000000000000000000000030783030313132323333000000000000000000000000000000000000000000003078303031313232333331323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3078303030303132333132330000000000000000000000000000000000000000000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000003307830000000000000000000000000000000000000000000000000000000000030783030313132323333000000000000000000000000000000000000000000003078303031313232333331323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3078303030303132333132330000000000000000000000000000000000000000"
             }
           ]}
        end
      )

      request =
        get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-read", %{
          "from" => "0xBb36c792B9B45Aaf8b848A1392B0d6559202729E"
        })

      assert response = json_response(request, 200)

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "names" => ["address"],
               "outputs" => [
                 %{
                   "type" => "address",
                   "value" => "0xfffffffffffffffffffffffffffffffffffffffe"
                 }
               ],
               "name" => "getCaller",
               "inputs" => [],
               "method_id" => "ab470f05"
             } in response

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
               "name" => "isWhitelist",
               "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}],
               "method_id" => "c683630d"
             } in response

      assert %{
               "inputs" => [],
               "method_id" => "2e64cec1",
               "name" => "retrieve",
               "names" => [
                 [
                   "struct Storage.TransactionReceipt",
                   [
                     "txHash",
                     "blockNumber",
                     "blockHash",
                     "transactionIndex",
                     "from",
                     "to",
                     "gasUsed",
                     "status",
                     ["logs", ["from", "topics", "data"]]
                   ]
                 ]
               ],
               "outputs" => [
                 %{
                   "type" =>
                     "tuple[bytes32,uint256,bytes32,uint256,address,address,uint256,bool,tuple[address,bytes32[],bytes][]]",
                   "value" => [
                     "0xfe6a43fa23a0269092cbf97cb908e1d5a49a18fd6942baf2467fb5b221e39ab2",
                     "1000",
                     "0xfe6a43fa23a0269092cbf97cb908e1d5a49a18fd6942baf2467fb5b221e39ab2",
                     "10",
                     "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                     "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                     "123123",
                     "true",
                     [
                       [
                         "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                         [
                           "0x3078300000000000000000000000000000000000000000000000000000000000",
                           "0x3078303031313232333300000000000000000000000000000000000000000000",
                           "0x3078303031313232333331323300000000000000000000000000000000000000"
                         ],
                         "0x307830303030313233313233"
                       ],
                       [
                         "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                         [
                           "0x3078300000000000000000000000000000000000000000000000000000000000",
                           "0x3078303031313232333300000000000000000000000000000000000000000000",
                           "0x3078303031313232333331323300000000000000000000000000000000000000"
                         ],
                         "0x307830303030313233313233"
                       ],
                       [
                         "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                         [
                           "0x3078300000000000000000000000000000000000000000000000000000000000",
                           "0x3078303031313232333300000000000000000000000000000000000000000000",
                           "0x3078303031313232333331323300000000000000000000000000000000000000"
                         ],
                         "0x307830303030313233313233"
                       ]
                     ]
                   ]
                 }
               ],
               "stateMutability" => "view",
               "type" => "function"
             } in response

      refute %{"type" => "fallback"} in response
      refute %{"type" => "receive"} in response
    end

    test "ensure read-methods are not duplicated", %{conn: conn} do
      abi = [
        %{
          "inputs" => [],
          "name" => "test",
          "outputs" => [
            %{"internalType" => "uint256", "name" => "", "type" => "uint256"}
          ],
          "stateMutability" => "pure",
          "type" => "function"
        }
      ]

      id =
        abi
        |> ABI.parse_specification()
        |> Enum.at(0)
        |> Map.fetch!(:method_id)

      target_contract = insert(:smart_contract, abi: abi)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: "eth_call", params: _params}], _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000000000009d37020ac9049a8040"
             }
           ]}
        end
      )

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-read")

      assert response = json_response(request, 200)

      assert response == [
               %{
                 "type" => "function",
                 "stateMutability" => "pure",
                 "outputs" => [
                   %{
                     "type" => "uint256",
                     "value" => "2900102562052921000000"
                   }
                 ],
                 "name" => "test",
                 "names" => ["uint256"],
                 "inputs" => [],
                 "method_id" => Base.encode16(id, case: :lower)
               }
             ]
    end

    test "get array of addresses within read-methods", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "payable" => false,
          "outputs" => [%{"type" => "address[]", "name" => ""}],
          "name" => "getOwners",
          "inputs" => [],
          "constant" => true
        }
      ]

      id =
        abi
        |> ABI.parse_specification()
        |> Enum.at(0)
        |> Map.fetch!(:method_id)

      target_contract = insert(:smart_contract, abi: abi)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: "eth_call", params: _params}], _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000400000000000000000000000064631b5d259ead889e8b06d12c8b74742804e5f1000000000000000000000000234fe7224ce480ca97d01897311b8c3d35162f8600000000000000000000000087877d9d68c9e014ea81e6f4a8bd44528484567d0000000000000000000000009c28f1bb95d7e7fe88e6e8458d53be127cc2dc4f"
             }
           ]}
        end
      )

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-read")
      assert response = json_response(request, 200)

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "payable" => false,
               "names" => [nil],
               "outputs" => [
                 %{
                   "type" => "address[]",
                   "value" => [
                     "0x64631b5d259ead889e8b06d12c8b74742804e5f1",
                     "0x234fe7224ce480ca97d01897311b8c3d35162f86",
                     "0x87877d9d68c9e014ea81e6f4a8bd44528484567d",
                     "0x9c28f1bb95d7e7fe88e6e8458d53be127cc2dc4f"
                   ]
                 }
               ],
               "name" => "getOwners",
               "inputs" => [],
               "constant" => true,
               "method_id" => Base.encode16(id, case: :lower)
             } in response
    end

    test "get correct bytes value 1", %{conn: conn} do
      abi = [
        %{
          "inputs" => [],
          "name" => "all_messages_hash",
          "outputs" => [
            %{
              "internalType" => "bytes32",
              "name" => "",
              "type" => "bytes32"
            }
          ],
          "stateMutability" => "view",
          "type" => "function"
        }
      ]

      id_1 =
        abi
        |> ABI.parse_specification()
        |> Enum.at(0)
        |> Map.fetch!(:method_id)

      target_contract = insert(:smart_contract, abi: abi)
      address_hash_string = to_string(target_contract.address_hash)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [
                 %{data: "0x1dd69d06", to: ^address_hash_string},
                 "latest"
               ]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000000"
             }
           ]}
        end
      )

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-read")
      assert response = json_response(request, 200)

      assert %{
               "inputs" => [],
               "name" => "all_messages_hash",
               "outputs" => [
                 %{
                   "value" => "0x0000000000000000000000000000000000000000000000000000000000000000",
                   "type" => "bytes32"
                 }
               ],
               "stateMutability" => "view",
               "type" => "function",
               "method_id" => Base.encode16(id_1, case: :lower),
               "names" => ["bytes32"]
             } in response
    end

    test "get correct bytes value 2", %{conn: conn} do
      abi = [
        %{
          "inputs" => [],
          "name" => "FRAUD_STRING",
          "outputs" => [
            %{
              "internalType" => "bytes",
              "name" => "",
              "type" => "bytes"
            }
          ],
          "stateMutability" => "view",
          "type" => "function"
        }
      ]

      id_2 =
        abi
        |> ABI.parse_specification()
        |> Enum.at(0)
        |> Map.fetch!(:method_id)

      target_contract = insert(:smart_contract, abi: abi)
      address_hash_string = to_string(target_contract.address_hash)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [
                 %{data: "0x46b2eb9b", to: ^address_hash_string},
                 "latest"
               ]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result:
                 "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000322d2d5468697320697320612062616420737472696e672e204e6f626f64792073617973207468697320737472696e672e2d2d0000000000000000000000000000"
             }
           ]}
        end
      )

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-read")
      assert response = json_response(request, 200)

      assert %{
               "inputs" => [],
               "name" => "FRAUD_STRING",
               "outputs" => [
                 %{
                   "value" =>
                     "0x2d2d5468697320697320612062616420737472696e672e204e6f626f64792073617973207468697320737472696e672e2d2d",
                   "type" => "bytes"
                 }
               ],
               "stateMutability" => "view",
               "type" => "function",
               "method_id" => Base.encode16(id_2, case: :lower),
               "names" => ["bytes"]
             } in response
    end

    test "Digests tuple array type", %{conn: conn} do
      abi = [
        %{
          "inputs" => [],
          "stateMutability" => "nonpayable",
          "type" => "constructor"
        },
        %{
          "inputs" => [
            %{
              "internalType" => "address",
              "name" => "",
              "type" => "address"
            }
          ],
          "name" => "contributions",
          "outputs" => [
            %{
              "internalType" => "uint256",
              "name" => "iterations",
              "type" => "uint256"
            }
          ],
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "inputs" => [
            %{
              "internalType" => "uint256",
              "name" => "",
              "type" => "uint256"
            }
          ],
          "name" => "contributors",
          "outputs" => [
            %{
              "internalType" => "address",
              "name" => "",
              "type" => "address"
            }
          ],
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "inputs" => [],
          "name" => "getTopTenContributors",
          "outputs" => [
            %{
              "internalType" => "address[10]",
              "name" => "",
              "type" => "address[10]"
            },
            %{
              "internalType" => "uint256[10]",
              "name" => "",
              "type" => "uint256[10]"
            }
          ],
          "stateMutability" => "view",
          "type" => "function"
        }
      ]

      # id_2 =
      #   abi
      #   |> ABI.parse_specification()
      #   |> Enum.at(0)
      #   |> Map.fetch!(:method_id)

      target_contract = insert(:smart_contract, abi: abi)
      address_hash_string = to_string(target_contract.address_hash)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [
                 %{data: "0x94ec8506", to: ^address_hash_string},
                 "latest"
               ]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result:
                 "0x000000000000000000000000af1caf51d49b0e63d1ff7e5d4ed6ea26d15f3f9d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
             }
           ]}
        end
      )

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-read")
      assert response = json_response(request, 200)

      assert [
               %{
                 "inputs" => [%{"internalType" => "address", "name" => "", "type" => "address"}],
                 "method_id" => "42e94c90",
                 "name" => "contributions",
                 "outputs" => [%{"internalType" => "uint256", "name" => "iterations", "type" => "uint256"}],
                 "stateMutability" => "view",
                 "type" => "function"
               },
               %{
                 "inputs" => [%{"internalType" => "uint256", "name" => "", "type" => "uint256"}],
                 "method_id" => "3cb5d100",
                 "name" => "contributors",
                 "outputs" => [%{"internalType" => "address", "name" => "", "type" => "address"}],
                 "stateMutability" => "view",
                 "type" => "function"
               },
               %{
                 "inputs" => [],
                 "method_id" => "94ec8506",
                 "name" => "getTopTenContributors",
                 "names" => ["address[10]", "uint256[10]"],
                 "outputs" => [
                   %{
                     "type" => "address[10]",
                     "value" => [
                       "0xaf1caf51d49b0e63d1ff7e5d4ed6ea26d15f3f9d",
                       "0x0000000000000000000000000000000000000000",
                       "0x0000000000000000000000000000000000000000",
                       "0x0000000000000000000000000000000000000000",
                       "0x0000000000000000000000000000000000000000",
                       "0x0000000000000000000000000000000000000000",
                       "0x0000000000000000000000000000000000000000",
                       "0x0000000000000000000000000000000000000000",
                       "0x0000000000000000000000000000000000000000",
                       "0x0000000000000000000000000000000000000000"
                     ]
                   },
                   %{
                     "type" => "uint256[10]",
                     "value" => ["1", "0", "0", "0", "0", "0", "0", "0", "0", "0"]
                   }
                 ],
                 "stateMutability" => "view",
                 "type" => "function"
               }
             ] == response
    end
  end

  describe "/smart-contracts/{address_hash}/query-read-method" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request =
        post(conn, "/api/v2/smart-contracts/#{address.hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request =
        post(conn, "/api/v2/smart-contracts/0x/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "return 404 on unverified contract", %{conn: conn} do
      address = insert(:contract_address)

      request =
        post(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "query-read-method", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }
           ]}
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{
               "is_error" => false,
               "result" => %{"names" => ["bool"], "output" => [%{"type" => "bool", "value" => "true"}]}
             } == response
    end

    test "query complex response", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [
            %{
              "type" => "tuple",
              "name" => "",
              "internalType" => "struct Storage.TransactionReceipt",
              "components" => [
                %{"type" => "bytes32", "name" => "txHash", "internalType" => "bytes32"},
                %{"type" => "uint256", "name" => "blockNumber", "internalType" => "uint256"},
                %{"type" => "bytes32", "name" => "blockHash", "internalType" => "bytes32"},
                %{"type" => "uint256", "name" => "transactionIndex", "internalType" => "uint256"},
                %{"type" => "address", "name" => "from", "internalType" => "address"},
                %{"type" => "address", "name" => "to", "internalType" => "address"},
                %{"type" => "uint256", "name" => "gasUsed", "internalType" => "uint256"},
                %{"type" => "bool", "name" => "status", "internalType" => "bool"},
                %{
                  "type" => "tuple[]",
                  "name" => "logs",
                  "internalType" => "struct Storage.Log[]",
                  "components" => [
                    %{"type" => "address", "name" => "from", "internalType" => "address"},
                    %{"type" => "bytes32[]", "name" => "topics", "internalType" => "bytes32[]"},
                    %{"type" => "bytes", "name" => "data", "internalType" => "bytes"}
                  ]
                }
              ]
            }
          ],
          "name" => "retrieve",
          "inputs" => []
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{to: _address_hash, from: "0xBb36c792B9B45Aaf8b848A1392B0d6559202729E"}, _]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020fe6a43fa23a0269092cbf97cb908e1d5a49a18fd6942baf2467fb5b221e39ab200000000000000000000000000000000000000000000000000000000000003e8fe6a43fa23a0269092cbf97cb908e1d5a49a18fd6942baf2467fb5b221e39ab2000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000001e0f30000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000003307830000000000000000000000000000000000000000000000000000000000030783030313132323333000000000000000000000000000000000000000000003078303031313232333331323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3078303030303132333132330000000000000000000000000000000000000000000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000003307830000000000000000000000000000000000000000000000000000000000030783030313132323333000000000000000000000000000000000000000000003078303031313232333331323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3078303030303132333132330000000000000000000000000000000000000000000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000003307830000000000000000000000000000000000000000000000000000000000030783030313132323333000000000000000000000000000000000000000000003078303031313232333331323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3078303030303132333132330000000000000000000000000000000000000000"
             }
           ]}
        end
      )

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => [],
          "method_id" => "2e64cec1",
          "from" => "0xBb36c792B9B45Aaf8b848A1392B0d6559202729E"
        })

      assert response = json_response(request, 200)

      assert %{
               "is_error" => false,
               "result" => %{
                 "names" => [
                   [
                     "struct Storage.TransactionReceipt",
                     [
                       "txHash",
                       "blockNumber",
                       "blockHash",
                       "transactionIndex",
                       "from",
                       "to",
                       "gasUsed",
                       "status",
                       ["logs", ["from", "topics", "data"]]
                     ]
                   ]
                 ],
                 "output" => [
                   %{
                     "type" =>
                       "tuple[bytes32,uint256,bytes32,uint256,address,address,uint256,bool,tuple[address,bytes32[],bytes][]]",
                     "value" => [
                       "0xfe6a43fa23a0269092cbf97cb908e1d5a49a18fd6942baf2467fb5b221e39ab2",
                       "1000",
                       "0xfe6a43fa23a0269092cbf97cb908e1d5a49a18fd6942baf2467fb5b221e39ab2",
                       "10",
                       "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                       "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                       "123123",
                       "true",
                       [
                         [
                           "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                           [
                             "0x3078300000000000000000000000000000000000000000000000000000000000",
                             "0x3078303031313232333300000000000000000000000000000000000000000000",
                             "0x3078303031313232333331323300000000000000000000000000000000000000"
                           ],
                           "0x307830303030313233313233"
                         ],
                         [
                           "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                           [
                             "0x3078300000000000000000000000000000000000000000000000000000000000",
                             "0x3078303031313232333300000000000000000000000000000000000000000000",
                             "0x3078303031313232333331323300000000000000000000000000000000000000"
                           ],
                           "0x307830303030313233313233"
                         ],
                         [
                           "0xbb36c792b9b45aaf8b848a1392b0d6559202729e",
                           [
                             "0x3078300000000000000000000000000000000000000000000000000000000000",
                             "0x3078303031313232333300000000000000000000000000000000000000000000",
                             "0x3078303031313232333331323300000000000000000000000000000000000000"
                           ],
                           "0x307830303030313233313233"
                         ]
                       ]
                     ]
                   }
                 ]
               }
             } == response
    end

    test "query-read-method with nonexistent method_id", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "00000000"
        })

      assert response = json_response(request, 200)

      assert %{
               "is_error" => true,
               "result" => %{"error" => "method_id does not exist"}
             } == response
    end

    test "query-read-method returns error 1", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:ok, [%{id: id, jsonrpc: "2.0", error: %{code: "12345", message: "Error message"}}]}
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{"is_error" => true, "result" => %{"code" => "12345", "message" => "Error message"}} == response
    end

    test "query-read-method returns error 2", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: _id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:error, {:bad_gateway, "request_url"}}
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)
      assert %{"is_error" => true, "result" => %{"error" => "Bad gateway"}} == response
    end

    test "query-read-method returns error 3", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: _id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          raise FunctionClauseError
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{"is_error" => true, "result" => %{"error" => "no function clause matches"}} == response
    end
  end

  describe "/smart-contracts/{address_hash}/methods-write" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/smart-contracts/#{address.hash}/methods-write")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/0x/methods-write")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "return 404 on unverified contract", %{conn: conn} do
      address = insert(:contract_address)

      TestHelper.get_eip1967_implementation_zero_addresses()
      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}/methods-write")
      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get write-methods", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        },
        %{"type" => "fallback"}
      ]

      target_contract = insert(:smart_contract, abi: abi)

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-write")
      assert response = json_response(request, 200)

      assert [
               %{
                 "method_id" => "49ba1b49",
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "outputs" => [],
                 "name" => "disableWhitelist",
                 "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
               },
               %{"type" => "fallback"}
             ] == response
    end
  end

  describe "/smart-contracts/{address_hash}/methods-[write/read] & query read method custom abi" do
    setup %{conn: conn} do
      auth = build(:auth)

      {:ok, user} = Identity.find_or_create(auth)

      {:ok, conn: Plug.Test.init_test_session(conn, current_user: user)}
    end

    test "get write method from custom abi", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      custom_abi = :custom_abi |> build() |> Map.replace("abi", abi)

      conn
      |> post(
        "/api/account/v2/user/custom_abis",
        custom_abi
      )

      request =
        get(conn, "/api/v2/smart-contracts/#{custom_abi["contract_address_hash"]}/methods-write", %{
          "is_custom_abi" => true
        })

      assert response = json_response(request, 200)

      assert [
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "outputs" => [],
                 "name" => "disableWhitelist",
                 "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}],
                 "method_id" => "49ba1b49"
               }
             ] == response
    end

    test "get read method from custom abi", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      custom_abi = :custom_abi |> build() |> Map.replace("abi", abi)

      conn
      |> post(
        "/api/account/v2/user/custom_abis",
        custom_abi
      )

      blockchain_eth_call_mock()

      request =
        get(conn, "/api/v2/smart-contracts/#{custom_abi["contract_address_hash"]}/methods-read", %{
          "is_custom_abi" => true
        })

      assert response = json_response(request, 200)

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "names" => ["address"],
               "outputs" => [
                 %{
                   "type" => "address",
                   "value" => "0xfffffffffffffffffffffffffffffffffffffffe"
                 }
               ],
               "name" => "getCaller",
               "inputs" => [],
               "method_id" => "ab470f05"
             } in response

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
               "name" => "isWhitelist",
               "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}],
               "method_id" => "c683630d"
             } in response
    end

    test "query read method", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      custom_abi = :custom_abi |> build() |> Map.replace("abi", abi)

      conn
      |> post(
        "/api/account/v2/user/custom_abis",
        custom_abi
      )

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }
           ]}
        end
      )

      request =
        post(conn, "/api/v2/smart-contracts/#{custom_abi["contract_address_hash"]}/query-read-method", %{
          "contract_type" => "regular",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "is_custom_abi" => true,
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{
               "is_error" => false,
               "result" => %{"names" => ["bool"], "output" => [%{"type" => "bool", "value" => "true"}]}
             } == response
    end

    test "query read method 1", %{conn: conn} do
      abi = [
        %{
          "inputs" => [
            %{
              "internalType" => "uint256",
              "name" => "amountIn",
              "type" => "uint256"
            },
            %{
              "internalType" => "address[]",
              "name" => "path",
              "type" => "address[]"
            }
          ],
          "name" => "getAmountsOut",
          "outputs" => [
            %{
              "internalType" => "uint256[]",
              "name" => "amounts",
              "type" => "uint256[]"
            }
          ],
          "stateMutability" => "view",
          "type" => "function"
        }
      ]

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [
                 %{
                   data:
                     "0xd06ca61f00000000000000000000000000000000000000000000003635c9adc5dea0000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000909fd75ce23a7e61787fe2763652935f921164610000000000000000000000009801eeb848987c0a8d6443912827bd36c288f8fb"
                 },
                 _
               ]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000003635c9adc5dea000000000000000000000000000000000000000000000000000000037240fc3496a65"
             }
           ]}
        end
      )

      target_contract = insert(:smart_contract, abi: abi)

      request =
        post(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/query-read-method", %{
          "contract_type" => "regular",
          "args" => [
            "1000000000000000000000",
            ["0x909Fd75Ce23a7e61787FE2763652935F92116461", "0x9801eeb848987c0a8d6443912827bd36c288f8fb"]
          ],
          "method_id" => "d06ca61f"
        })

      assert response = json_response(request, 200)

      assert %{
               "is_error" => false,
               "result" => %{
                 "names" => ["amounts"],
                 "output" => [
                   %{"type" => "uint256[]", "value" => ["1000000000000000000000", "15520773838563941"]}
                 ]
               }
             } == response
    end
  end

  describe "/smart-contracts/{address_hash}/methods-read-proxy" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/smart-contracts/#{address.hash}/methods-read-proxy")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/0x/methods-read-proxy")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "return 404 on unverified contract", %{conn: conn} do
      address = insert(:contract_address)

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}/methods-read-proxy")
      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get read-methods", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      mock_logic_storage_pointer_request(false, target_contract.address_hash)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: id, method: "eth_call", params: [%{to: _address_hash}, _]}], _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"
             }
           ]}
        end
      )

      contract = insert(:smart_contract)
      request = get(conn, "/api/v2/smart-contracts/#{contract.address_hash}/methods-read-proxy")
      assert response = json_response(request, 200)

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "names" => ["address"],
               "outputs" => [
                 %{
                   "type" => "address",
                   "value" => "0xfffffffffffffffffffffffffffffffffffffffe"
                 }
               ],
               "name" => "getCaller",
               "inputs" => [],
               "method_id" => "ab470f05"
             } in response

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
               "name" => "isWhitelist",
               "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}],
               "method_id" => "c683630d"
             } in response
    end
  end

  describe "/smart-contracts/{address_hash}/query-read-method proxy" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request =
        post(conn, "/api/v2/smart-contracts/#{address.hash}/query-read-method", %{
          "contract_type" => "proxy",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request =
        post(conn, "/api/v2/smart-contracts/0x/query-read-method", %{
          "contract_type" => "proxy",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "query-read-method", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      mock_logic_storage_pointer_request(false, target_contract.address_hash)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [
                 %{
                   data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe",
                   to: _address_hash
                 },
                 _
               ]
             }
           ],
           _opts ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x0000000000000000000000000000000000000000000000000000000000000001"
             }
           ]}
        end
      )

      contract = insert(:smart_contract)

      request =
        post(conn, "/api/v2/smart-contracts/#{contract.address_hash}/query-read-method", %{
          "contract_type" => "proxy",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{
               "is_error" => false,
               "result" => %{"names" => ["bool"], "output" => [%{"type" => "bool", "value" => "true"}]}
             } == response
    end

    test "query-read-method returns error 1", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      mock_logic_storage_pointer_request(false, target_contract.address_hash)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:ok, [%{id: id, jsonrpc: "2.0", error: %{code: "12345", message: "Error message"}}]}
        end
      )

      contract = insert(:smart_contract)

      request =
        post(conn, "/api/v2/smart-contracts/#{contract.address_hash}/query-read-method", %{
          "contract_type" => "proxy",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{"is_error" => true, "result" => %{"code" => "12345", "message" => "Error message"}} == response
    end

    test "query-read-method returns error 2", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      mock_logic_storage_pointer_request(false, target_contract.address_hash)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: _id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          {:error, {:bad_gateway, "request_url"}}
        end
      )

      contract = insert(:smart_contract)

      request =
        post(conn, "/api/v2/smart-contracts/#{contract.address_hash}/query-read-method", %{
          "contract_type" => "proxy",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)
      assert %{"is_error" => true, "result" => %{"error" => "Bad gateway"}} == response
    end

    test "query-read-method returns error 3", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      mock_logic_storage_pointer_request(false, target_contract.address_hash)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: _id,
               method: "eth_call",
               params: [%{data: "0xc683630d000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"}, _]
             }
           ],
           _opts ->
          raise FunctionClauseError
        end
      )

      contract = insert(:smart_contract)

      request =
        post(conn, "/api/v2/smart-contracts/#{contract.address_hash}/query-read-method", %{
          "contract_type" => "proxy",
          "args" => ["0xfffffffffffffffffffffffffffffffffffffffe"],
          "method_id" => "c683630d"
        })

      assert response = json_response(request, 200)

      assert %{"is_error" => true, "result" => %{"error" => "no function clause matches"}} == response
    end
  end

  describe "/smart-contracts/{address_hash}/methods-write-proxy" do
    test "get 404 on non existing SC", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/smart-contracts/#{address.hash}/methods-write-proxy")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/0x/methods-write-proxy")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "return 404 on unverified contract", %{conn: conn} do
      address = insert(:contract_address)

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}/methods-write-proxy")
      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get write-methods", %{conn: conn} do
      abi = [
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
          "name" => "getCaller",
          "inputs" => []
        },
        %{
          "type" => "function",
          "stateMutability" => "view",
          "outputs" => [%{"type" => "bool", "name" => "", "internalType" => "bool"}],
          "name" => "isWhitelist",
          "inputs" => [%{"type" => "address", "name" => "_address", "internalType" => "address"}]
        },
        %{
          "type" => "function",
          "stateMutability" => "nonpayable",
          "outputs" => [],
          "name" => "disableWhitelist",
          "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      mock_logic_storage_pointer_request(false, target_contract.address_hash)

      contract = insert(:smart_contract)

      request = get(conn, "/api/v2/smart-contracts/#{contract.address_hash}/methods-write-proxy")
      assert response = json_response(request, 200)

      assert [
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "outputs" => [],
                 "name" => "disableWhitelist",
                 "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}],
                 "method_id" => "49ba1b49"
               }
             ] == response
    end
  end

  describe "/smart-contracts" do
    test "get [] on empty db", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts")

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    test "get correct smart contract", %{conn: conn} do
      smart_contract = insert(:smart_contract)
      request = get(conn, "/api/v2/smart-contracts")

      assert %{"items" => [sc], "next_page_params" => nil} = json_response(request, 200)
      compare_item(smart_contract, sc)
      assert sc["address"]["is_verified"] == true
      assert sc["address"]["is_contract"] == true
    end

    test "get filtered smart contracts when flags are set", %{conn: conn} do
      smart_contract = insert(:smart_contract, abi: nil, language: :yul)
      insert(:smart_contract)
      request = get(conn, "/api/v2/smart-contracts", %{"filter" => "yul"})

      assert %{"items" => [sc], "next_page_params" => nil} = json_response(request, 200)
      compare_item(smart_contract, sc)
      assert sc["address"]["is_verified"] == true
      assert sc["address"]["is_contract"] == true
    end

    test "get filtered smart contracts when language is set", %{conn: conn} do
      smart_contract = insert(:smart_contract, is_vyper_contract: true, language: :vyper)
      insert(:smart_contract, is_vyper_contract: false)
      request = get(conn, "/api/v2/smart-contracts", %{"filter" => "vyper"})

      assert %{"items" => [sc], "next_page_params" => nil} = json_response(request, 200)
      compare_item(smart_contract, sc)
      assert sc["address"]["is_verified"] == true
      assert sc["address"]["is_contract"] == true
    end

    if Application.compile_env(:explorer, :chain_type) == :zilliqa do
      test "get filtered scilla smart contracts when language is set", %{conn: conn} do
        smart_contract = insert(:smart_contract, language: :scilla)
        insert(:smart_contract)
        request = get(conn, "/api/v2/smart-contracts", %{"filter" => "scilla"})

        assert %{"items" => [sc], "next_page_params" => nil} = json_response(request, 200)
        compare_item(smart_contract, sc)
        assert sc["address"]["is_verified"] == true
        assert sc["address"]["is_contract"] == true
      end
    end

    test "check pagination", %{conn: conn} do
      smart_contracts =
        for _ <- 0..50 do
          insert(:smart_contract)
        end

      request = get(conn, "/api/v2/smart-contracts")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/smart-contracts", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, smart_contracts)
    end

    test "ignores wrong ordering params", %{conn: conn} do
      smart_contracts =
        for _ <- 0..50 do
          insert(:smart_contract)
        end

      ordering_params = %{"sort" => "foo", "order" => "bar"}

      request = get(conn, "/api/v2/smart-contracts", ordering_params)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/smart-contracts", ordering_params |> Map.merge(response["next_page_params"]))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, smart_contracts)
    end

    test "can order by balance ascending", %{conn: conn} do
      smart_contracts =
        for i <- 0..50 do
          address = insert(:address, fetched_coin_balance: i)
          insert(:smart_contract, address_hash: address.hash, address: address)
        end
        |> Enum.reverse()

      ordering_params = %{"sort" => "balance", "order" => "asc"}

      request = get(conn, "/api/v2/smart-contracts", ordering_params)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/smart-contracts", ordering_params |> Map.merge(response["next_page_params"]))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, smart_contracts)
    end

    test "can order by balance descending", %{conn: conn} do
      smart_contracts =
        for i <- 0..50 do
          address = insert(:address, fetched_coin_balance: i)
          insert(:smart_contract, address_hash: address.hash, address: address)
        end

      ordering_params = %{"sort" => "balance", "order" => "desc"}

      request = get(conn, "/api/v2/smart-contracts", ordering_params)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/smart-contracts", ordering_params |> Map.merge(response["next_page_params"]))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, smart_contracts)
    end

    test "can order by transaction count ascending", %{conn: conn} do
      smart_contracts =
        for i <- 0..50 do
          address = insert(:address, transactions_count: i)
          insert(:smart_contract, address_hash: address.hash, address: address)
        end
        |> Enum.reverse()

      ordering_params = %{"sort" => "transactions_count", "order" => "asc"}

      request = get(conn, "/api/v2/smart-contracts", ordering_params)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/smart-contracts", ordering_params |> Map.merge(response["next_page_params"]))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, smart_contracts)
    end

    test "can order by transaction count descending", %{conn: conn} do
      smart_contracts =
        for i <- 0..50 do
          address = insert(:address, transactions_count: i)
          insert(:smart_contract, address_hash: address.hash, address: address)
        end

      ordering_params = %{"sort" => "transactions_count", "order" => "desc"}

      request = get(conn, "/api/v2/smart-contracts", ordering_params)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/smart-contracts", ordering_params |> Map.merge(response["next_page_params"]))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, smart_contracts)
    end
  end

  describe "/smart-contracts/counters" do
    test "fetch counters", %{conn: conn} do
      request = get(conn, "/api/v2/smart-contracts/counters")

      assert %{
               "smart_contracts" => _,
               "new_smart_contracts_24h" => _,
               "verified_smart_contracts" => _,
               "new_verified_smart_contracts_24h" => _
             } = json_response(request, 200)
    end
  end

  defp compare_item(%SmartContract{} = smart_contract, json) do
    assert smart_contract.compiler_version == json["compiler_version"]

    assert smart_contract.optimization == json["optimization_enabled"]

    assert json["language"] == smart_contract_language(smart_contract)
    assert json["verified_at"]
    assert !is_nil(smart_contract.constructor_arguments) == json["has_constructor_args"]
    assert Address.checksum(smart_contract.address_hash) == json["address"]["hash"]
  end

  defp check_paginated_response(first_page_resp, second_page_resp, list) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
  end

  defp blockchain_eth_call_mock do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [%{id: id, method: "eth_call", params: _params}], _opts ->
        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: "0x000000000000000000000000fffffffffffffffffffffffffffffffffffffffe"
           }
         ]}
      end
    )
  end

  defp smart_contract_language(smart_contract) do
    cond do
      smart_contract.is_vyper_contract ->
        "vyper"

      is_nil(smart_contract.abi) ->
        "yul"

      is_nil(smart_contract.language) ->
        "solidity"

      true ->
        to_string(smart_contract.language)
    end
  end

  defp mock_logic_storage_pointer_request(error?, address_hash) do
    response = "0x000000000000000000000000#{address_hash |> to_string() |> String.replace("0x", "")}"

    EthereumJSONRPC.Mox
    |> TestHelper.mock_logic_storage_pointer_request(error?, response)
  end

  defp prepare_implementation(items) when is_list(items) do
    Enum.map(items, &prepare_implementation/1)
  end

  defp prepare_implementation(%{"address" => _, "name" => _} = implementation) do
    case Application.get_env(:explorer, :chain_type) do
      :filecoin ->
        Map.put(implementation, "filecoin_robust_address", nil)

      _ ->
        implementation
    end
  end

  defp prepare_implementation(other), do: other
end
