defmodule Explorer.SmartContract.PublisherTest do
  use ExUnit.Case, async: true

  use Explorer.DataCase

  doctest Explorer.SmartContract.Publisher

  alias Explorer.Chain.{ContractMethod, SmartContract}
  alias Explorer.{Factory, Repo}
  alias Explorer.SmartContract.Publisher

  describe "publish/2" do
    test "with valid data creates a smart_contract" do
      contract_code_info = Factory.contract_code_info()

      contract_address = insert(:contract_address, contract_code: contract_code_info.bytecode)

      valid_attrs = %{
        "contract_source_code" => contract_code_info.source_code,
        "compiler_version" => contract_code_info.version,
        "name" => contract_code_info.name,
        "optimization" => contract_code_info.optimized
      }

      response = Publisher.publish(contract_address.hash, valid_attrs)
      assert {:ok, %SmartContract{} = smart_contract} = response

      assert smart_contract.address_hash == contract_address.hash
      assert smart_contract.name == valid_attrs["name"]
      assert smart_contract.compiler_version == valid_attrs["compiler_version"]
      assert smart_contract.optimization == valid_attrs["optimization"]
      assert smart_contract.contract_source_code == valid_attrs["contract_source_code"]
      assert is_nil(smart_contract.constructor_arguments)
      assert smart_contract.abi == contract_code_info.abi
    end

    test "corresponding contract_methods are created for the abi" do
      contract_code_info = Factory.contract_code_info()

      contract_address = insert(:contract_address, contract_code: contract_code_info.bytecode)

      valid_attrs = %{
        "contract_source_code" => contract_code_info.source_code,
        "compiler_version" => contract_code_info.version,
        "name" => contract_code_info.name,
        "optimization" => contract_code_info.optimized
      }

      response = Publisher.publish(contract_address.hash, valid_attrs)
      assert {:ok, %SmartContract{} = smart_contract} = response

      Enum.each(contract_code_info.abi, fn selector ->
        [parsed] = ABI.parse_specification([selector])

        assert Repo.get_by(ContractMethod, abi: selector, identifier: parsed.method_id)
      end)
    end

    test "creates a smart contract with constructor arguments" do
      contract_code_info = Factory.contract_code_info()

      contract_address = insert(:contract_address, contract_code: contract_code_info.bytecode)

      constructor_arguments = "0102030405"

      params = %{
        "contract_source_code" => contract_code_info.source_code,
        "compiler_version" => contract_code_info.version,
        "name" => contract_code_info.name,
        "optimization" => contract_code_info.optimized,
        "constructor_arguments" => constructor_arguments
      }

      :transaction
      |> insert(
        created_contract_address_hash: contract_address.hash,
        input: contract_code_info.bytecode <> constructor_arguments
      )
      |> with_block()

      response = Publisher.publish(contract_address.hash, params)
      assert {:ok, %SmartContract{} = smart_contract} = response

      assert smart_contract.constructor_arguments == constructor_arguments
    end

    test "with invalid data returns error changeset" do
      address_hash = ""

      invalid_attrs = %{
        "contract_source_code" => "",
        "compiler_version" => "",
        "name" => "",
        "optimization" => ""
      }

      assert {:error, %Ecto.Changeset{}} = Publisher.publish(address_hash, invalid_attrs)
    end

    test "validates and creates smart contract with external libraries" do
      contract_data =
        "#{System.cwd!()}/test/support/fixture/smart_contract/compiler_tests.json"
        |> File.read!()
        |> Jason.decode!()
        |> List.first()

      compiler_version = contract_data["compiler_version"]
      external_libraries = contract_data["external_libraries"]
      name = contract_data["name"]
      optimize = contract_data["optimize"]
      contract = contract_data["contract"]
      expected_bytecode = contract_data["expected_bytecode"]

      contract_address = insert(:contract_address, contract_code: "0x" <> expected_bytecode)

      params = %{
        "contract_source_code" => contract,
        "compiler_version" => compiler_version,
        "name" => name,
        "optimization" => optimize
      }

      external_libraries_form_params =
        external_libraries
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {{name, address}, index}, acc ->
          name_key = "library#{index + 1}_name"
          address_key = "library#{index + 1}_address"

          acc
          |> Map.put(name_key, name)
          |> Map.put(address_key, address)
        end)

      response = Publisher.publish(contract_address.hash, params, external_libraries_form_params)
      assert {:ok, %SmartContract{} = smart_contract} = response
    end
  end
end
