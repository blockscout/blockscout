# credo:disable-for-this-file
defmodule Explorer.SmartContract.Verifier.ConstructorArguments do
  @moduledoc """
  Smart contract contrstructor arguments verification logic.
  """


  def find_constructor_arguments(creation_code, _abi, _contract_source_code, _contract_name) do

    creation_code_new = creation_code |> String.slice(128..-1)
    for <<x::binary-64 <- creation_code_new>> do
      Base.decode16!(x, case: :lower)
      |> :binary.bin_to_list
      |> Enum.reverse()
      |> :binary.list_to_bin
      |> Base.encode16(case: :lower)
    end |> Enum.join()

  end
end
