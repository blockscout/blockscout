defmodule Explorer.SmartContract.Geas.PublisherTest do
  use ExUnit.Case, async: true

  use Explorer.DataCase

  doctest Explorer.SmartContract.Geas.Publisher

  @moduletag timeout: :infinity

  alias Explorer.Chain.{SmartContract}
  alias Explorer.SmartContract.Geas.Publisher

  setup do
    configuration = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)
    Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, enabled: false)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, configuration)
    end)
  end

  describe "process_rust_verifier_response/6" do
    test "successfully processes a GEAS verification response" do
      contract_address = insert(:contract_address)

      geas_response = %{
        "fileName" => "src/consolidations/main.eas",
        "contractName" => "ConsolidationRequestPredeploy",
        "compilerVersion" => "v0.2.2",
        "compilerSettings" => "{}",
        "sourceType" => "GEAS",
        "sourceFiles" => %{
          "src/common/fake_expo.eas" => "// Test GEAS contract source code",
          "src/consolidations/ctor.eas" => "// Test GEAS contract source code",
          "src/consolidations/main.eas" => "// Test GEAS contract source code"
        },
        "abi" =>
          Jason.encode!([
            %{
              "type" => "function",
              "name" => "test_function",
              "inputs" => [],
              "outputs" => [%{"type" => "bool"}],
              "stateMutability" => "view"
            }
          ]),
        "constructorArguments" => nil,
        "matchType" => "PARTIAL",
        "compilationArtifacts" => "{}",
        "creationInputArtifacts" => "{}",
        "deployedBytecodeArtifacts" => "{}",
        "isBlueprint" => false,
        "libraries" => %{}
      }

      response =
        Publisher.process_rust_verifier_response(
          geas_response,
          contract_address.hash,
          %{},
          # save_file_path?
          true,
          # is_standard_json?
          true,
          # automatically_verified?
          true
        )

      assert {:ok, %SmartContract{} = smart_contract} = response

      assert smart_contract.address_hash == contract_address.hash
      assert smart_contract.name == "ConsolidationRequestPredeploy"
      assert smart_contract.compiler_version == "v0.2.2"
      assert smart_contract.file_path == "src/consolidations/main.eas"

      assert smart_contract.contract_source_code ==
               "// Test GEAS contract source code"

      assert smart_contract.language == :geas
      assert smart_contract.verified_via_eth_bytecode_db == true
      assert smart_contract.partially_verified == true
      assert is_list(smart_contract.abi)
      assert length(smart_contract.abi) == 1
    end
  end
end
