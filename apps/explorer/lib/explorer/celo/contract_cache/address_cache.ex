defmodule Explorer.Celo.AddressCache do
  @moduledoc "Behaviour to cache celo core contract addresses"

  @doc """
  Fetch a contract address for a given name
  """
  @callback contract_address(String.t()) :: String.t()

  @doc """
  Return whether this address represents a known core contract address
  """
  @callback is_core_contract_address?(String.t()) :: boolean()
  @callback is_core_contract_address?(Explorer.Chain.Hash.Address.t()) :: boolean()

  @doc """
    Add a name + address to the cache
  """
  @callback update_cache(String.t(), String.t()) :: any()

  # credo:disable-for-next-line
  @implementation Application.compile_env!(:explorer, __MODULE__)

  defdelegate contract_address(contract_name), to: @implementation
  defdelegate is_core_contract_address?(address), to: @implementation
  defdelegate update_cache(name, address), to: @implementation
end
