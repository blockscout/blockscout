if Application.compile_env(:explorer, :chain_type) !== :zksync do
  defmodule Explorer.SmartContract.Vyper.PublisherTest do
    use ExUnit.Case, async: true

    use Explorer.DataCase

    doctest Explorer.SmartContract.Vyper.Publisher

    @moduletag timeout: :infinity

    alias Explorer.Chain.{SmartContract}
    alias Explorer.Factory
    alias Explorer.SmartContract.Vyper.Publisher

    setup do
      configuration = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)
      Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, enabled: false)
      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour, configuration)
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      end)
    end

    describe "publish/2" do
      test "with valid data creates a smart_contract" do
        contract_code_info = Factory.contract_code_info_vyper()

        contract_address = insert(:contract_address, contract_code: contract_code_info.bytecode)

        :transaction
        |> insert(created_contract_address_hash: contract_address.hash, input: contract_code_info.tx_input)
        |> with_block(status: :ok)

        valid_attrs = %{
          "contract_source_code" => contract_code_info.source_code,
          "compiler_version" => contract_code_info.version,
          "name" => contract_code_info.name
        }

        response = Publisher.publish(contract_address.hash, valid_attrs)
        assert {:ok, %SmartContract{} = smart_contract} = response

        assert smart_contract.address_hash == contract_address.hash
        assert smart_contract.name == valid_attrs["name"]
        assert smart_contract.compiler_version == valid_attrs["compiler_version"]
        assert smart_contract.contract_source_code == valid_attrs["contract_source_code"]
        assert is_nil(smart_contract.constructor_arguments)
        assert smart_contract.abi == contract_code_info.abi
      end

      test "allows to re-verify vyper contracts" do
        contract_code_info = Factory.contract_code_info_vyper()

        contract_address = insert(:contract_address, contract_code: contract_code_info.bytecode)

        :transaction
        |> insert(created_contract_address_hash: contract_address.hash, input: contract_code_info.tx_input)
        |> with_block(status: :ok)

        valid_attrs = %{
          "contract_source_code" => contract_code_info.source_code,
          "compiler_version" => contract_code_info.version,
          "name" => contract_code_info.name
        }

        response = Publisher.publish(contract_address.hash, valid_attrs)
        assert {:ok, %SmartContract{}} = response

        updated_name = "AnotherContractName"

        valid_attrs =
          valid_attrs
          |> Map.put("name", updated_name)

        response = Publisher.publish(contract_address.hash, valid_attrs)
        assert {:ok, %SmartContract{} = smart_contract} = response

        assert smart_contract.name == valid_attrs["name"]
      end
    end
  end
end
