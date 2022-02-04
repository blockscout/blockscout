defmodule Explorer.Celo.AddressCache do
  @moduledoc "Behaviour to cache celo core contract addresses"

  @doc """
  Fetch a contract address for a given name
  """
  @callback contract_address(String.t()) :: String.t()

  # credo:disable-for-next-line
  @implementation Application.fetch_env!(:explorer, __MODULE__)

  defdelegate contract_address(contract_name), to: @implementation
end
