defmodule Explorer.SmartContract.Writer do
  @moduledoc """
  Generates smart-contract transactions
  """

  alias Explorer.Chain

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
  def write_functions_proxy(contract_address_hash) do
    abi =
      contract_address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi)

    implementation_abi = Chain.get_implementation_abi_from_proxy(contract_address_hash, abi)

    case implementation_abi do
      nil ->
        []

      _ ->
        implementation_abi
        |> filter_write_functions()
    end
  end

  def write_function?(function) do
    !event?(function) && !constructor?(function) &&
      (payable?(function) || nonpayable?(function))
  end

  defp filter_write_functions(abi) do
    abi
    |> Enum.filter(&write_function?(&1))
  end

  defp event?(function), do: function["type"] == "event"
  defp constructor?(function), do: function["type"] == "constructor"
  defp payable?(function), do: function["stateMutability"] == "payable" || function["payable"]

  defp nonpayable?(function),
    do:
      function["stateMutability"] == "nonpayable" ||
        (!function["payable"] && !function["constant"] && !function["stateMutability"])
end
