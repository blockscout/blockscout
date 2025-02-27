defmodule Explorer.SmartContract.Writer do
  @moduledoc """
  Generates smart-contract transactions
  """

  alias Explorer.Chain.{Hash, SmartContract}
  alias Explorer.SmartContract.Helper

  @spec write_functions(SmartContract.t()) :: [%{}]
  def write_functions(%SmartContract{abi: abi}) do
    case abi do
      nil ->
        []

      _ ->
        abi
        |> filter_write_functions()
    end
  end

  @spec write_functions_proxy(Hash.t() | String.t()) :: [%{}]
  def write_functions_proxy(implementation_address_hash_string, options \\ []) do
    implementation_abi = SmartContract.get_abi(implementation_address_hash_string, options)

    case implementation_abi do
      nil ->
        []

      _ ->
        implementation_abi
        |> filter_write_functions()
    end
  end

  def write_function?(function) do
    !Helper.error?(function) && !Helper.event?(function) && !Helper.constructor?(function) &&
      (Helper.payable?(function) || Helper.nonpayable?(function))
  end

  def filter_write_functions(abi) when is_list(abi) do
    abi
    |> Enum.filter(&write_function?(&1))
  end

  def filter_write_functions(_), do: []
end
