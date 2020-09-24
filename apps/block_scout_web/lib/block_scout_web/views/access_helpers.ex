defmodule BlockScoutWeb.AccessHelpers do
  @moduledoc """
  Helpers to restrict access to some pages filtering by address
  """

  alias BlockScoutWeb.WebRouter.Helpers
  alias Plug.Conn

  defp get_restricted_key(conn) do
    conn_with_params = Conn.fetch_query_params(conn)
    conn_with_params.query_params["key"]
  end

  def restricted_access?(address_hash, params) do
    formatted_address_hash = String.downcase(address_hash)
    key = if params && Map.has_key?(params, "key"), do: Map.get(params, "key"), else: nil

    restricted_list_var = Application.get_env(:block_scout_web, :restricted_list)
    restricted_list = (restricted_list_var && String.split(restricted_list_var, ",")) || []

    formatted_restricted_list =
      restricted_list
      |> Enum.map(fn addr ->
        String.downcase(addr)
      end)

    address_restricted =
      formatted_restricted_list
      |> Enum.member?(formatted_address_hash)

    correct_key = key && key == Application.get_env(:block_scout_web, :restricted_list_key)

    if address_restricted && !correct_key, do: {:restricted_access, true}, else: {:ok, false}
  end

  def get_path(conn, path, template, address_hash) do
    basic_args = [conn, template, address_hash]
    key = get_restricted_key(conn)
    # credo:disable-for-next-line
    full_args = if key, do: basic_args ++ [%{:key => key}], else: basic_args

    apply(Helpers, path, full_args)
  end

  def get_path(conn, path, template, address_hash, additional_params) do
    basic_args = [conn, template, address_hash]
    key = get_restricted_key(conn)
    full_additional_params = if key, do: Map.put(additional_params, :key, key), else: additional_params
    # credo:disable-for-next-line
    full_args = basic_args ++ [full_additional_params]

    apply(Helpers, path, full_args)
  end
end
