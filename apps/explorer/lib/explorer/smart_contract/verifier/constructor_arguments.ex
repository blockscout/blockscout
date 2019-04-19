defmodule Explorer.SmartContract.Verifier.ConstructorArguments do
  @moduledoc """
  Smart contract contrstructor arguments verification logic.
  """

  alias Explorer.Chain

  def verify(address_hash, arguments_data) do
    arguments_data = String.replace(arguments_data, "0x", "")
    creation_input_data = Chain.contract_creation_input_data(address_hash)

    expected_arguments_data =
      creation_input_data
      |> String.split("0029")
      |> List.last()
      |> String.replace("0x", "")

    expected_arguments_data == arguments_data
  end
end
