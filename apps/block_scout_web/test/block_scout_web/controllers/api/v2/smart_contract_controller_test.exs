defmodule BlockScoutWeb.API.V2.SmartContractControllerTest do
  use BlockScoutWeb.ConnCase
  use BlockScoutWeb.ChannelCase, async: false

  import Mox

  alias BlockScoutWeb.AddressContractView
  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Chain.{Address, SmartContract}
  alias Plug.Conn

  setup :set_mox_from_context

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

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      response = json_response(request, 200)

      assert response ==
               %{
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

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      response = json_response(request, 200)

      assert response ==
               %{
                 "is_self_destructed" => false,
                 "deployed_bytecode" => to_string(address.contract_code),
                 "creation_bytecode" =>
                   "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
               }
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

      correct_response = %{
        "verified_twin_address_hash" => nil,
        "is_verified" => true,
        "is_changed_bytecode" => false,
        "is_partially_verified" => target_contract.partially_verified,
        "is_fully_verified" => true,
        "is_verified_via_sourcify" => target_contract.verified_via_sourcify,
        "is_vyper_contract" => target_contract.is_vyper_contract,
        "minimal_proxy_address_hash" => nil,
        "sourcify_repo_url" =>
          if(target_contract.verified_via_sourcify,
            do: AddressContractView.sourcify_repo_url(target_contract.address_hash, target_contract.partially_verified)
          ),
        "can_be_visualized_via_sol2uml" => false,
        "name" => target_contract && target_contract.name,
        "compiler_version" => target_contract.compiler_version,
        "optimization_enabled" => if(target_contract.is_vyper_contract, do: nil, else: target_contract.optimization),
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
        "abi" => target_contract.abi
      }

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(target_contract.address_hash)}")
      response = json_response(request, 200)

      assert correct_response == response
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
          ]
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
        "minimal_proxy_address_hash" => nil,
        "sourcify_repo_url" =>
          if(target_contract.verified_via_sourcify,
            do: AddressContractView.sourcify_repo_url(target_contract.address_hash, target_contract.partially_verified)
          ),
        "can_be_visualized_via_sol2uml" => false,
        "name" => target_contract && target_contract.name,
        "compiler_version" => target_contract.compiler_version,
        "optimization_enabled" => if(target_contract.is_vyper_contract, do: nil, else: target_contract.optimization),
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
          ["0x2cf6e7c9ec35d0b08a1062e13854f74b1aaae54e", %{"name" => "_implementationAddress", "type" => "address"}]
        ],
        "is_self_destructed" => false,
        "deployed_bytecode" =>
          "0x6080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "creation_bytecode" =>
          "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029",
        "abi" => target_contract.abi
      }

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(target_contract.address_hash)}")
      response = json_response(request, 200)

      assert correct_response == response
    end

    test "get smart-contract data from twin without constructor args", %{conn: conn} do
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
        "minimal_proxy_address_hash" => nil,
        "sourcify_repo_url" => nil,
        "can_be_visualized_via_sol2uml" => false,
        "name" => target_contract && target_contract.name,
        "compiler_version" => target_contract.compiler_version,
        "optimization_enabled" => if(target_contract.is_vyper_contract, do: nil, else: target_contract.optimization),
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
        "abi" => target_contract.abi
      }

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      response = json_response(request, 200)

      assert correct_response == response
    end

    test "automatically verify contract via Eth Bytecode Interface", %{conn: conn} do
      bypass = Bypass.open()

      eth_bytecode_response = File.read!("./test/support/fixture/smart_contract/eth_bytecode_db_search_response.json")

      old_env = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterface)

      Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterface,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
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

      Bypass.expect(bypass, "POST", "/api/v2/bytecodes/sources:search", fn conn ->
        Conn.resp(conn, 200, eth_bytecode_response)
      end)

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")

      assert_receive %Phoenix.Socket.Message{
                       payload: %{},
                       event: "smart_contract_was_verified",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      response = json_response(request, 200)

      assert response ==
               %{
                 "is_self_destructed" => false,
                 "deployed_bytecode" => to_string(address.contract_code),
                 "creation_bytecode" =>
                   "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582061b7676067d537e410bb704932a9984739a959416170ea17bda192ac1218d2790029"
               }

      request = get(conn, "/api/v2/smart-contracts/#{Address.checksum(address.hash)}")
      assert %{"is_verified" => true} = json_response(request, 200)

      Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterface, old_env)
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
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      blockchain_eth_call_mock()

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-read")
      assert response = json_response(request, 200)

      assert %{
               "type" => "function",
               "stateMutability" => "view",
               "outputs" => [
                 %{
                   "type" => "address",
                   "name" => "",
                   "internalType" => "address",
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
               "outputs" => [
                 %{
                   "type" => "address[]",
                   "name" => "",
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
               "result" => %{"names" => ["bool"], "output" => [%{"type" => "bool", "value" => true}]}
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
        }
      ]

      target_contract = insert(:smart_contract, abi: abi)

      request = get(conn, "/api/v2/smart-contracts/#{target_contract.address_hash}/methods-write")
      assert response = json_response(request, 200)

      assert [
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "outputs" => [],
                 "name" => "disableWhitelist",
                 "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
               }
             ] == response
    end
  end

  describe "/smart-contracts/{address_hash}/methods-[write/read] & query read method custom abi" do
    setup %{conn: conn} do
      auth = build(:auth)

      {:ok, user} = UserFromAuth.find_or_create(auth)

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
        "/api/account/v1/user/custom_abis",
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
                 "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
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
        "/api/account/v1/user/custom_abis",
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
               "outputs" => [
                 %{
                   "type" => "address",
                   "name" => "",
                   "internalType" => "address",
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
        "/api/account/v1/user/custom_abis",
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
               "result" => %{"names" => ["bool"], "output" => [%{"type" => "bool", "value" => true}]}
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

      expect(EthereumJSONRPC.Mox, :json_rpc, fn %{
                                                  id: 0,
                                                  method: "eth_getStorageAt",
                                                  params: [
                                                    _,
                                                    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                                    "latest"
                                                  ]
                                                },
                                                _options ->
        {:ok, "0x000000000000000000000000#{target_contract.address_hash |> to_string() |> String.replace("0x", "")}"}
      end)

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
               "outputs" => [
                 %{
                   "type" => "address",
                   "name" => "",
                   "internalType" => "address",
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

      expect(EthereumJSONRPC.Mox, :json_rpc, fn %{
                                                  id: 0,
                                                  method: "eth_getStorageAt",
                                                  params: [
                                                    _,
                                                    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                                    "latest"
                                                  ]
                                                },
                                                _options ->
        {:ok, "0x000000000000000000000000#{target_contract.address_hash |> to_string() |> String.replace("0x", "")}"}
      end)

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
               "result" => %{"names" => ["bool"], "output" => [%{"type" => "bool", "value" => true}]}
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

      expect(EthereumJSONRPC.Mox, :json_rpc, fn %{
                                                  id: 0,
                                                  method: "eth_getStorageAt",
                                                  params: [
                                                    _,
                                                    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                                    "latest"
                                                  ]
                                                },
                                                _options ->
        {:ok, "0x000000000000000000000000#{target_contract.address_hash |> to_string() |> String.replace("0x", "")}"}
      end)

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

      expect(EthereumJSONRPC.Mox, :json_rpc, fn %{
                                                  id: 0,
                                                  method: "eth_getStorageAt",
                                                  params: [
                                                    _,
                                                    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                                    "latest"
                                                  ]
                                                },
                                                _options ->
        {:ok, "0x000000000000000000000000#{target_contract.address_hash |> to_string() |> String.replace("0x", "")}"}
      end)

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

      expect(EthereumJSONRPC.Mox, :json_rpc, fn %{
                                                  id: 0,
                                                  method: "eth_getStorageAt",
                                                  params: [
                                                    _,
                                                    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                                    "latest"
                                                  ]
                                                },
                                                _options ->
        {:ok, "0x000000000000000000000000#{target_contract.address_hash |> to_string() |> String.replace("0x", "")}"}
      end)

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

      expect(EthereumJSONRPC.Mox, :json_rpc, fn %{
                                                  id: 0,
                                                  method: "eth_getStorageAt",
                                                  params: [
                                                    _,
                                                    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                                                    "latest"
                                                  ]
                                                },
                                                _options ->
        {:ok, "0x000000000000000000000000#{target_contract.address_hash |> to_string() |> String.replace("0x", "")}"}
      end)

      contract = insert(:smart_contract)

      request = get(conn, "/api/v2/smart-contracts/#{contract.address_hash}/methods-write-proxy")
      assert response = json_response(request, 200)

      assert [
               %{
                 "type" => "function",
                 "stateMutability" => "nonpayable",
                 "outputs" => [],
                 "name" => "disableWhitelist",
                 "inputs" => [%{"type" => "bool", "name" => "disable", "internalType" => "bool"}]
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

    assert if(smart_contract.is_vyper_contract, do: nil, else: smart_contract.optimization) ==
             json["optimization_enabled"]

    assert json["language"] == if(smart_contract.is_vyper_contract, do: "vyper", else: "solidity")
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
end
