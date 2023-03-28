defmodule Explorer.AccessHelper do
  @moduledoc """
    Helper to restrict access to some pages filtering by address
  """

  def restricted_access?(address_hash, params) do
    restricted_list_var = Application.get_env(:explorer, :restricted_list)
    restricted_list = (restricted_list_var && String.split(restricted_list_var, ",")) || []

    if Enum.count(restricted_list) > 0 do
      formatted_restricted_list =
        restricted_list
        |> Enum.map(fn addr ->
          String.downcase(addr)
        end)

      formatted_address_hash = String.downcase(address_hash)

      address_restricted =
        formatted_restricted_list
        |> Enum.member?(formatted_address_hash)

      key = if params && Map.has_key?(params, "key"), do: Map.get(params, "key"), else: nil
      correct_key = key && key == Application.get_env(:explorer, :restricted_list_key)

      if address_restricted && !correct_key, do: {:restricted_access, true}, else: {:ok, false}
    else
      {:ok, false}
    end
  end
end
