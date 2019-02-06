defmodule Explorer.SmartContract.Verifier.ConstructorArgumentsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.Data
  alias Explorer.SmartContract.Verifier.ConstructorArguments

  describe "verify/3" do
    test "verifies construct arguments" do
      bytecode = "0x0102030"
      constructor_arguments = "0x405"
      address = insert(:address)

      input = %Data{
        bytes: <<1, 2, 3, 4, 5>>
      }

      :transaction
      |> insert(created_contract_address_hash: address.hash, input: input)
      |> with_block()

      assert ConstructorArguments.verify(address.hash, bytecode, constructor_arguments)
    end
  end
end
