defmodule Explorer.SmartContract.PublisherTest do
  use ExUnit.Case, async: true

  use Explorer.DataCase

  doctest Explorer.SmartContract.Publisher

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Publisher
  alias Explorer.Factory

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
      assert smart_contract.abi != nil
    end

    test "with invalid data returns error changeset" do
      address_hash = ""

      invalid_attrs = %{
        "contract_source_code" => "",
        "compiler" => "",
        "name" => "",
        "optimization" => ""
      }

      assert {:error, %Ecto.Changeset{}} = Publisher.publish(address_hash, invalid_attrs)
    end
  end
end
