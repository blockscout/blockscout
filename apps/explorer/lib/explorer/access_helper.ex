defmodule Explorer.AccessHelper do
  @moduledoc """
    Helper to restrict access to some pages filtering by address
  """

  alias Explorer.Chain
  alias Explorer.Chain.Fetcher.AddressesBlacklist

  @doc """
  Checks if access is restricted based on the provided address_hash_string and map with request params.

  ## Parameters
  - `binary()`: A binary input, representing address_hash_string to check for restricted access.
  - `nil | map()`: An optional map that may contain admin keys to bypass access restrictions.

  ## Returns
  - `{:ok, false}`: If access is not restricted.
  - `{:restricted_access, true}`: If access is restricted.
  """
  @spec restricted_access?(binary(), nil | map()) :: {:ok, false} | {:restricted_access, true}
  def restricted_access?("", _), do: {:ok, false}

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def restricted_access?(address_hash_string, params) do
    restricted_list_var = Application.get_env(:explorer, :addresses_blacklist)
    addresses_blacklist = (restricted_list_var && String.split(restricted_list_var, ",")) || []

    key = if params && Map.has_key?(params, "key"), do: Map.get(params, "key"), else: nil
    correct_key = key && key == Application.get_env(:explorer, :addresses_blacklist_key)

    {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)
    blacklisted? = AddressesBlacklist.blacklisted?(address_hash)

    cond do
      blacklisted? ->
        if correct_key, do: {:ok, false}, else: {:restricted_access, true}

      Enum.empty?(addresses_blacklist) ->
        {:ok, false}

      true ->
        formatted_restricted_list =
          addresses_blacklist
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
