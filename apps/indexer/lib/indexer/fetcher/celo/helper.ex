defmodule Indexer.Fetcher.Celo.Helper do
  @moduledoc """
  Helper functions for the Celo fetchers.
  """

  @doc """
  Extracts the method ID from an ABI specification.

  ## Parameters
  - `method` ([map()] | map()): The ABI specification, either as a single map
    or a list containing one map.

  ## Returns
  - `binary()`: The method ID extracted from the ABI specification.

  ## Examples

      iex> Indexer.Fetcher.Celo.Helper.abi_to_method_id([%{"name" => "transfer", "type" => "function", "inputs" => [%{"name" => "to", "type" => "address"}]}])
      <<26, 105, 82, 48>>

  """
  @spec abi_to_method_id([map()] | map()) :: binary()
  def abi_to_method_id([method]), do: abi_to_method_id(method)

  def abi_to_method_id(method) when is_map(method) do
    [parsed_method] = ABI.parse_specification([method])
    parsed_method.method_id
  end
end
