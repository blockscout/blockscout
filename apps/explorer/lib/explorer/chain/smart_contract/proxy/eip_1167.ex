defmodule Explorer.Chain.SmartContract.Proxy.EIP1167 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1167 (Minimal Proxy Contract)
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}

  import Ecto.Query, only: [from: 2]

  @doc """
  Get implementation address following EIP-1167
  """
  @spec get_implementation_address(Hash.Address.t(), Keyword.t()) :: SmartContract.t() | nil
  def get_implementation_address(address_hash, options \\ []) do
    case Chain.select_repo(options).get(Address, address_hash) do
      nil ->
        nil

      target_address ->
        contract_code = target_address.contract_code

        case contract_code do
          %Chain.Data{bytes: contract_code_bytes} ->
            contract_bytecode = Base.encode16(contract_code_bytes, case: :lower)

            get_proxy_eip_1167(contract_bytecode, options)

          _ ->
            nil
        end
    end
  end

  defp get_proxy_eip_1167(contract_bytecode, options) do
    case contract_bytecode do
      "363d3d373d3d3d363d73" <> <<template_address::binary-size(40)>> <> _ ->
        template_address = "0x" <> template_address

        query =
          from(
            smart_contract in SmartContract,
            where: smart_contract.address_hash == ^template_address,
            select: smart_contract
          )

        query
        |> Chain.select_repo(options).one(timeout: 10_000)

      _ ->
        nil
    end
  end
end
