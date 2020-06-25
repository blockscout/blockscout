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
        |> Enum.filter(
          &(&1["type"] !== "event" &&
              (&1["stateMutability"] == "nonpayable" || &1["stateMutability"] == "payable" || &1["payable"] ||
                 (!&1["payable"] && !&1["constant"] && !&1["stateMutability"])))
        )
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
        |> Enum.filter(
          &(&1["type"] !== "event" &&
              (&1["stateMutability"] == "nonpayable" || &1["stateMutability"] == "payable" || &1["payable"] ||
                 (!&1["payable"] && !&1["constant"] && !&1["stateMutability"])))
        )
    end
  end
end
