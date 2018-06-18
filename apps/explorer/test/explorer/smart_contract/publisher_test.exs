defmodule Explorer.SmartContract.PublisherTest do
  use ExUnit.Case, async: true

  use Explorer.DataCase

  doctest Explorer.SmartContract.Publisher

  alias Explorer.Chain.{SmartContract, Hash}
  alias Explorer.SmartContract.Publisher

  describe "publish/2" do
    test "with valid data creates a smart_contract" do
      address_hash = "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c"

      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      created_contract_address = insert(:address, hash: address_hash, contract_code: smart_contract_bytecode)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: created_contract_address,
        created_contract_code: smart_contract_bytecode
      )

      valid_attrs = %{
        "contract_source_code" =>
          "pragma solidity ^0.4.23;\r\n\r\ncontract SimpleStorage {\r\n    uint storedData;\r\n\r\n    function set(uint x) public {\r\n        storedData = x;\r\n    }\r\n\r\n    function get() public constant returns (uint) {\r\n        return storedData;\r\n    }\r\n}",
        "compiler" => "0.4.24",
        "name" => "SimpleStorage",
        "optimization" => false
      }

      assert {:ok, %SmartContract{} = smart_contract} = Publisher.publish(address_hash, valid_attrs)
      assert smart_contract.name == valid_attrs["name"]
      assert Hash.to_string(smart_contract.address_hash) == address_hash
      assert smart_contract.compiler_version == valid_attrs["compiler"]
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
