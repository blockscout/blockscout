defmodule Explorer.SmartContract.Verifier.ConstructorArgumentsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.Data
  alias Explorer.SmartContract.Verifier.ConstructorArguments

  describe "verify/3" do
    test "verifies constructor arguments" do
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

  test "veriies constructor constructor arguments with whisper data" do
    bytecode = "0x0102035d943c575be8a2aee2bb7737a765fdd2c6e49b74cd2c92ab0fa8e4282d1a75ae0029"
    constructor_arguments = "0x0405"
    address = insert(:address)

    input = %Data{
      bytes:
        <<1, 2, 3, 93, 148, 60, 87, 91, 232, 162, 174, 226, 187, 119, 55, 167, 101, 253, 210, 198, 228, 155, 116, 205,
          44, 146, 171, 15, 168, 228, 40, 45, 26, 117, 174, 0, 41, 4, 5>>
    }

    :transaction
    |> insert(created_contract_address_hash: address.hash, input: input)
    |> with_block()

    assert ConstructorArguments.verify(address.hash, bytecode, constructor_arguments)
  end
end
