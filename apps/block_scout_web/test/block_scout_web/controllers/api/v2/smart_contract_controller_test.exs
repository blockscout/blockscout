defmodule BlockScoutWeb.API.V2.SmartContractControllerTest do
  use BlockScoutWeb.ConnCase, async: false
  use BlockScoutWeb.ChannelCase, async: false

  import Mox

  alias BlockScoutWeb.AddressContractView
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.TestHelper
  alias Plug.Conn

  setup :set_mox_from_context

  setup :verify_on_exit!

  setup_all do
    # Create the mock safely with try-catch to avoid errors if already mocked
    try do
      :meck.new(Explorer.Chain.SmartContract, [:passthrough])
    catch
      :error, {:already_started, _pid} -> :ok
    end

    on_exit(fn ->
      try do
        :meck.unload(Explorer.Chain.SmartContract)
      catch
        # Ignore any errors when unloading
        _, _ -> :ok
      end
    end)

    :ok
  end

  describe "/smart-contracts/{address_hash}" do
    setup do
      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      end)
    end

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
                 "deployed_bytecode" => to_string(address.contract_code),
                 "creation_bytecode" => nil,
                 "creation_status" => "success"
               }

      insert(:transaction,
        created_contract_address_hash: address.hash,
        input:
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
      )
      |> with_block(status: :ok)

      TestHelper.get_eip1967_implementation_error_response()

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      response = json_response(request, 200)

      assert response ==
               %{
                 "proxy_type" => nil,
                 "implementations" => [],
                 "deployed_bytecode" => to_string(address.contract_code),
                 "creation_bytecode" =>
                   "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
                 "creation_status" => "success"
               }
    end

    test "get unverified smart-contract with failed creation status", %{conn: conn} do
      address = insert(:address, contract_code: "0x")

      creation_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"

      insert(:transaction,
        created_contract_address_hash: address.hash,
        input: creation_bytecode
      )
      |> with_block(status: :error)

      TestHelper.get_eip1967_implementation_error_response()

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      response = json_response(request, 200)

      assert response ==
               %{
                 "proxy_type" => nil,
                 "implementations" => [],
                 "deployed_bytecode" => "0x",
                 "creation_bytecode" => creation_bytecode,
                 "creation_status" => "failed"
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
      json_response(request, 200)
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
      |> with_block(status: :ok)

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
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi,
        "proxy_type" => "eip1967",
        "implementations" => [
          %{
            "address_hash" => formatted_implementation_address_hash_string,
            "address" => formatted_implementation_address_hash_string,
            "name" => nil
          }
        ],
        "is_verified_via_eth_bytecode_db" => target_contract.verified_via_eth_bytecode_db,
        "is_verified_via_verifier_alliance" => target_contract.verified_via_verifier_alliance,
        "language" => target_contract |> SmartContract.language() |> to_string(),
        "license_type" => "none",
        "certified" => false,
        "is_blueprint" => false,
        "creation_status" => "success"
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
      |> with_block(status: :ok)

      correct_response = %{
        "verified_twin_address_hash" => nil,
        "is_verified" => true,
        "is_changed_bytecode" => false,
        "is_partially_verified" => target_contract.partially_verified,
        "is_fully_verified" => true,
        "is_verified_via_sourcify" => target_contract.verified_via_sourcify,
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
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi,
        "proxy_type" => nil,
        "implementations" => [],
        "is_verified_via_eth_bytecode_db" => target_contract.verified_via_eth_bytecode_db,
        "is_verified_via_verifier_alliance" => target_contract.verified_via_verifier_alliance,
        "language" => target_contract |> SmartContract.language() |> to_string(),
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
        "is_partially_verified" => false,
        "is_fully_verified" => false,
        "is_verified_via_sourcify" => false,
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
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi,
        "proxy_type" => nil,
        "implementations" => [],
        "is_verified_via_eth_bytecode_db" => target_contract.verified_via_eth_bytecode_db,
        "is_verified_via_verifier_alliance" => target_contract.verified_via_verifier_alliance,
        "language" => target_contract |> SmartContract.language() |> to_string(),
        "license_type" => "none",
        "certified" => false,
        "is_blueprint" => false
      }

      TestHelper.get_all_proxies_implementation_zero_addresses()

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
        "deployed_bytecode" => proxy_deployed_bytecode,
        "creation_bytecode" => proxy_transaction_input,
        "proxy_type" => "eip1167",
        "implementations" => [
          %{
            "address_hash" => Address.checksum(implementation_contract.address_hash),
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
      |> with_block(status: :ok)

      correct_response = %{
        "verified_twin_address_hash" => nil,
        "is_verified" => true,
        "is_changed_bytecode" => false,
        "is_partially_verified" => target_contract.partially_verified,
        "is_fully_verified" => true,
        "is_verified_via_sourcify" => target_contract.verified_via_sourcify,
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
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi,
        "proxy_type" => nil,
        "implementations" => [],
        "is_verified_via_eth_bytecode_db" => target_contract.verified_via_eth_bytecode_db,
        "is_verified_via_verifier_alliance" => target_contract.verified_via_verifier_alliance,
        "language" => target_contract |> SmartContract.language() |> to_string(),
        "license_type" => "none",
        "certified" => false,
        "is_blueprint" => true,
        "creation_status" => "success"
      }

      TestHelper.get_all_proxies_implementation_zero_addresses()

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(target_contract.address_hash)}")
      response = json_response(request, 200)

      result_props = correct_response |> Map.keys()

      for prop <- result_props do
        assert correct_response[prop] == response[prop]
      end
    end
  end

  test "doesn't get smart-contract implementation for 'Clones with immutable arguments' pattern", %{conn: conn} do
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

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
        %{
          "address_hash" => formatted_implementation_address_hash_string,
          "address" => formatted_implementation_address_hash_string,
          "name" => implementation_contract.name
        }
      ],
      "deployed_bytecode" => proxy_deployed_bytecode,
      "creation_bytecode" => proxy_transaction_input
    }

    request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(proxy_address.hash)}")
    response = json_response(request, 200)

    Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)

    result_props = correct_response |> Map.keys()

    for prop <- result_props do
      assert prepare_implementation(correct_response[prop]) == response[prop]
    end
  end

  if Application.compile_env(:explorer, :chain_type) !== :zksync do
    describe "/smart-contracts/{address_hash} <> eth_bytecode_db" do
      setup do
        old_fetcher_env = Application.get_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand)

        old_verifier_env =
          Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, [])

        old_chain_id = Application.get_env(:block_scout_web, :chain_id)

        {:ok, pid} = Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand.start_link([])
        bypass = Bypass.open()

        Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

        Application.put_env(:block_scout_web, :chain_id, 5)

        Application.put_env(
          :explorer,
          Explorer.SmartContract.RustVerifierInterfaceBehaviour,
          Keyword.merge(
            old_verifier_env,
            service_url: "http://localhost:#{bypass.port}",
            enabled: true,
            type: "eth_bytecode_db",
            eth_bytecode_db?: true
          )
        )

        on_exit(fn ->
          Application.put_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand, old_fetcher_env)
          Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, old_verifier_env)
          Application.put_env(:block_scout_web, :chain_id, old_chain_id)
          Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
          Bypass.down(bypass)
        end)

        {:ok, bypass: bypass}
      end

      test "automatically verify contract", %{conn: conn, bypass: bypass} do
        eth_bytecode_response = File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_response.json")

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block(status: :ok)

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.V2.UserSocket
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
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
                   "creation_status" => "success"
                 }

        TestHelper.get_all_proxies_implementation_zero_addresses()

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_partially_verified" => true} = response
        assert %{"is_fully_verified" => false} = response
      end

      test "automatically verify contract using search-all (ethBytecodeDbSources) endpoint", %{
        conn: conn,
        bypass: bypass
      } do
        eth_bytecode_response =
          File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_all_local_sources_response.json")

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block(status: :ok)

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.V2.UserSocket
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
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
                   "creation_status" => "success"
                 }

        TestHelper.get_all_proxies_implementation_zero_addresses()

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
      end

      test "automatically verify contract using search-all (sourcifySources) endpoint", %{conn: conn, bypass: bypass} do
        eth_bytecode_response =
          File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_all_sourcify_sources_response.json")

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block(status: :ok)

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.V2.UserSocket
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search_all", fn conn ->
          Conn.resp(conn, 200, eth_bytecode_response)
        end)

        TestHelper.get_all_proxies_implementation_zero_addresses()

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
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
                   "creation_status" => "success"
                 }

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"is_verified" => true} = response
        assert %{"is_verified_via_eth_bytecode_db" => true} = response
        assert %{"is_verified_via_sourcify" => true} = response
        assert %{"is_partially_verified" => true} = response
        assert %{"is_fully_verified" => false} = response
        assert response["file_path"] == "Test.sol"
      end

      test "automatically verify contract using search-all (sourcifySources with libraries) endpoint", %{
        conn: conn,
        bypass: bypass
      } do
        eth_bytecode_response =
          File.read!(
            "./test/support/fixture/smart_contract/eth_bytecode_db_search_all_sourcify_sources_with_libs_response.json"
          )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block(status: :ok)

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.V2.UserSocket
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
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
                   "creation_status" => "success"
                 }

        TestHelper.get_all_proxies_implementation_zero_addresses()

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
      end

      test "automatically verify contract using search-all (allianceSources) endpoint", %{conn: conn, bypass: bypass} do
        eth_bytecode_response =
          File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_all_alliance_sources_response.json")

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block(status: :ok)

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.V2.UserSocket
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
                     prepare_implementation(%{
                       "address_hash" => formatted_implementation_address_hash_string,
                       "address" => formatted_implementation_address_hash_string,
                       "name" => nil
                     })
                   ],
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
                   "creation_status" => "success"
                 }

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"proxy_type" => "eip1967"} = response

        assert %{
                 "implementations" => [
                   %{
                     "address_hash" => ^formatted_implementation_address_hash_string,
                     "address" => ^formatted_implementation_address_hash_string,
                     "name" => nil
                   }
                 ]
               } =
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
      end

      test "automatically verify contract using search-all (prefer sourcify FULL match) endpoint", %{
        conn: conn,
        bypass: bypass
      } do
        eth_bytecode_response =
          File.read!(
            "./test/support/fixture/smart_contract/eth_bytecode_db_search_all_alliance_sources_partial_response.json"
          )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block(status: :ok)

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.V2.UserSocket
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
                     prepare_implementation(%{
                       "address_hash" => formatted_implementation_address_hash_string,
                       "address" => formatted_implementation_address_hash_string,
                       "name" => nil
                     })
                   ],
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
                   "creation_status" => "success"
                 }

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"proxy_type" => "eip1967"} = response

        assert %{
                 "implementations" => [
                   %{
                     "address_hash" => ^formatted_implementation_address_hash_string,
                     "address" => ^formatted_implementation_address_hash_string,
                     "name" => nil
                   }
                 ]
               } =
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
      end

      test "automatically verify contract using search-all (take eth bytecode db FULL match) endpoint", %{
        conn: conn,
        bypass: bypass
      } do
        eth_bytecode_response =
          File.read!(
            "./test/support/fixture/smart_contract/eth_bytecode_db_search_all_alliance_sources_partial_response_eth_bdb_full.json"
          )

        address = insert(:contract_address)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block(status: :ok)

        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.V2.UserSocket
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
                     prepare_implementation(%{
                       "address_hash" => formatted_implementation_address_hash_string,
                       "address" => formatted_implementation_address_hash_string,
                       "name" => nil
                     })
                   ],
                   "deployed_bytecode" => to_string(address.contract_code),
                   "creation_bytecode" =>
                     "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
                   "creation_status" => "success"
                 }

        request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
        assert response = json_response(request, 200)
        assert %{"proxy_type" => "eip1967"} = response

        assert %{
                 "implementations" => [
                   %{
                     "address_hash" => ^formatted_implementation_address_hash_string,
                     "address" => ^formatted_implementation_address_hash_string,
                     "name" => nil
                   }
                 ]
               } =
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
      end

      test "check fetch interval for LookUpSmartContractSourcesOnDemand and use sources:search endpoint since chain_id is unset",
           %{conn: conn, bypass: bypass} do
        Application.put_env(:block_scout_web, :chain_id, nil)
        address = insert(:contract_address)
        topic = "addresses:#{address.hash}"

        {:ok, _reply, _socket} =
          BlockScoutWeb.V2.UserSocket
          |> socket("no_id", %{})
          |> subscribe_and_join(topic)

        insert(:transaction,
          created_contract_address_hash: address.hash,
          input:
            "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
        )
        |> with_block(status: :ok)

        Application.put_env(:explorer, Explorer.Chain.Fetcher.LookUpSmartContractSourcesOnDemand, fetch_interval: 0)

        Bypass.expect_once(bypass, "POST", "/api/v2/bytecodes/sources_search", fn conn ->
          Conn.resp(conn, 200, "{\"sources\": []}")
        end)

        TestHelper.get_all_proxies_implementation_zero_addresses()

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
      end
    end
  end

  for {state_name, migrations_finished?} <- [
        {"completed migrations", true},
        {"migrations in progress", false}
      ] do
    describe "/smart-contracts" <> " (with #{state_name})" do
      setup do
        :meck.expect(
          Explorer.Chain.SmartContract,
          :background_migrations_finished?,
          fn ->
            unquote(migrations_finished?)
          end
        )

        :ok
      end

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

      test "get filtered smart contracts when flag is set and language is not set", %{conn: conn} do
        smart_contracts = [
          {"solidity", insert(:smart_contract, is_vyper_contract: false, language: nil)},
          {"vyper", insert(:smart_contract, is_vyper_contract: true, language: nil)},
          {"yul", insert(:smart_contract, abi: nil, is_vyper_contract: false, language: nil)}
        ]

        for {filter, smart_contract} <- smart_contracts do
          request = get(conn, "/api/v2/smart-contracts", %{"filter" => filter})

          assert %{"items" => [sc], "next_page_params" => nil} = json_response(request, 200)
          compare_item(smart_contract, sc)
          assert sc["address"]["is_verified"] == true
          assert sc["address"]["is_contract"] == true
        end
      end

      test "get filtered smart contracts when flag is set and language is set", %{conn: conn} do
        smart_contract = insert(:smart_contract, is_vyper_contract: true, language: :vyper)
        insert(:smart_contract, is_vyper_contract: false, language: :solidity)
        request = get(conn, "/api/v2/smart-contracts", %{"filter" => "vyper"})

        assert %{"items" => [sc], "next_page_params" => nil} = json_response(request, 200)
        compare_item(smart_contract, sc)
        assert sc["address"]["is_verified"] == true
        assert sc["address"]["is_contract"] == true
      end

      test "get filtered smart contracts when flag is not set and language is set", %{conn: conn} do
        smart_contract = insert(:smart_contract, is_vyper_contract: nil, abi: nil, language: :yul)
        insert(:smart_contract, is_vyper_contract: nil, language: :vyper)
        insert(:smart_contract, is_vyper_contract: nil, language: :solidity)
        request = get(conn, "/api/v2/smart-contracts", %{"filter" => "yul"})

        assert %{"items" => [sc], "next_page_params" => nil} = json_response(request, 200)
        compare_item(smart_contract, sc)
        assert sc["address"]["is_verified"] == true
        assert sc["address"]["is_contract"] == true
      end

      if Application.compile_env(:explorer, :chain_type) == :zilliqa do
        test "get filtered scilla smart contracts when language is set", %{conn: conn} do
          smart_contract = insert(:smart_contract, language: :scilla, abi: nil)
          insert(:smart_contract)
          request = get(conn, "/api/v2/smart-contracts", %{"filter" => "scilla"})

          assert %{"items" => [sc], "next_page_params" => nil} = json_response(request, 200)
          compare_item(smart_contract, sc)
          assert sc["address"]["is_verified"] == true
          assert sc["address"]["is_contract"] == true
        end

        test "scilla contracts are not returned when yul filter is applied", %{conn: conn} do
          insert(:smart_contract, language: :scilla, abi: nil)
          request = get(conn, "/api/v2/smart-contracts", %{"filter" => "yul"})

          assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
        end
      end

      test "check pagination", %{conn: conn} do
        smart_contracts =
          for _ <- 0..50 do
            insert(:smart_contract)
          end
          |> Enum.sort_by(& &1.id)

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
          |> Enum.sort_by(& &1.id)

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
            address = insert(:address, fetched_coin_balance: i, verified: true)
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
            address = insert(:address, fetched_coin_balance: i, verified: true)
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
            address = insert(:address, transactions_count: i, verified: true)
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
            address = insert(:address, transactions_count: i, verified: true)
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

    assert json["language"] == smart_contract |> SmartContract.language() |> to_string()
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
