defmodule Explorer.SmartContract.Verifier.ConstructorArgumentsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.Data
  alias Explorer.SmartContract.Verifier.ConstructorArguments

  test "veriies constructor constructor arguments with whisper data" do
    constructor_arguments = Base.encode16(:crypto.strong_rand_bytes(64), case: :lower)
    address = insert(:address)

    input =
      "a165627a7a72305820" <>
        Base.encode16(:crypto.strong_rand_bytes(32), case: :lower) <> "0029" <> constructor_arguments

    input_data = %Data{
      bytes: Base.decode16!(input, case: :lower)
    }

    :transaction
    |> insert(created_contract_address_hash: address.hash, input: input_data)
    |> with_block()

    assert ConstructorArguments.verify(address.hash, constructor_arguments)
  end
end
