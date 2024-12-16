defmodule Explorer.AccessHelper do
  @moduledoc """
    Helper to restrict access to some pages filtering by address
  """

  alias Explorer.Chain
  alias Explorer.Chain.Fetcher.AddressesBlacklist

  @spec restricted_access?(binary(), nil | map()) :: {:ok, false} | {:restricted_access, true}
  def restricted_access?("", _), do: {:ok, false}

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def restricted_access?(address_hash_string, params) do
    restricted_list_var = Application.get_env(:explorer, :restricted_list)
    restricted_list = (restricted_list_var && String.split(restricted_list_var, ",")) || []

    key = if params && Map.has_key?(params, "key"), do: Map.get(params, "key"), else: nil
    correct_key = key && key == Application.get_env(:explorer, :restricted_list_key)

    {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)
    blacklisted? = AddressesBlacklist.blacklisted?(address_hash)

    cond do
      blacklisted? ->
        if correct_key, do: {:ok, false}, else: {:restricted_access, true}

      Enum.empty?(restricted_list) ->
        {:ok, false}

      true ->
        formatted_restricted_list =
          restricted_list
          |> Enum.map(fn addr ->
            String.downcase(addr)
          end)

        formatted_address_hash = String.downcase(address_hash_string)

        address_restricted =
          formatted_restricted_list
          |> Enum.member?(formatted_address_hash)

        if address_restricted && !correct_key, do: {:restricted_access, true}, else: {:ok, false}
    end
  end
end
