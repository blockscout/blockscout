defmodule Explorer.SmartContract.Verifier.ConstructorArguments do
  @moduledoc """
  Smart contract contrstructor arguments verification logic.
  """

  alias Explorer.Chain

  def verify(address_hash, arguments_data) do
    arguments_data = String.replace(arguments_data, "0x", "")

    address_hash
    |> Chain.contract_creation_input_data()
    |> String.replace("0x", "")
    |> extract_constructor_arguments()
    |> Kernel.==(arguments_data)
  end

  defp extract_constructor_arguments(<<>>), do: ""

  defp extract_constructor_arguments("a165627a7a72305820" <> <<_::binary-size(64)>> <> "0029" <> constructor_arguments) do
    constructor_arguments
  end

  defp extract_constructor_arguments(<<_::binary-size(2)>> <> rest) do
    extract_constructor_arguments(rest)
  end
end
