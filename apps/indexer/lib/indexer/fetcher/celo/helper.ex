defmodule Indexer.Fetcher.Celo.Helper do
  @moduledoc """
  Helper functions for the Celo fetchers.
  """

  @spec abi_to_method_id([map()] | map()) :: binary()
  def abi_to_method_id([method]), do: abi_to_method_id(method)

  def abi_to_method_id(method) when is_map(method) do
    [parsed_method] = ABI.parse_specification([method])
    parsed_method.method_id
  end
end
