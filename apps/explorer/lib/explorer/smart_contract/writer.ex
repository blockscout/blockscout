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
end
