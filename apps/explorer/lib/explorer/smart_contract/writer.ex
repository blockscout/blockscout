defmodule Explorer.SmartContract.Writer do
  @moduledoc """
  Generates smart-contract transactions
  """

  alias Explorer.Chain
  alias Explorer.SmartContract.Helper

  @spec write_functions(Hash.t()) :: [%{}]
  def write_functions(contract_address_hash) do
    abi =
      contract_address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi)

    case abi do
      nil ->
        []

      _ ->
        abi
        |> filter_write_functions()
    end
  end

  @spec write_functions_proxy(Hash.t()) :: [%{}]
  def write_functions_proxy(implementation_address_hash_string) do
    implementation_abi = Chain.get_implementation_abi(implementation_address_hash_string)

    case implementation_abi do
      nil ->
        []

      _ ->
        implementation_abi
        |> filter_write_functions()
    end
  end

  def write_function?(function) do
    !Helper.event?(function) && !Helper.constructor?(function) &&
      (Helper.payable?(function) || Helper.nonpayable?(function))
  end

  defp filter_write_functions(abi) do
    abi
    |> Enum.filter(&write_function?(&1))
  end
end
