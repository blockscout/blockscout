defmodule BlockScoutWeb.API.RPC.ENSController do
  use BlockScoutWeb, :controller

  use Explorer.Schema

  alias Explorer.Chain

  alias Explorer.ENS.NameRetriever

  def ensaddress(conn, params) do
    with {:name_param, {:ok, name_param}} <- fetch_name(params),
         {:address, {:ok, address}} <- {:address, NameRetriever.fetch_address_of(name_param)} do
      render(conn, "ensaddress.json", %{address: address})
    else
      {:name_param, :error} ->
        render(conn, :error, error: "Query parameter 'name' is required")

      {:address, {:error, error}} ->
        render(conn, :error, error: error)
    end
  end

  def ensname(conn, params) do
    with {:address_param, {:ok, address_param}} <- fetch_address(params),
         {:format, {:ok, _casted_address_hash}} <- to_address_hash(address_param),
         {:name, {:ok, name}} <- {:name, NameRetriever.fetch_name_of(address_param)} do
      render(conn, "ensname.json", %{name: name})
    else
      {:address_param, :error} ->
        render(conn, :error, error: "Query parameter 'address' is required")

      {:format, :error} ->
        render(conn, :error, error: "Invalid address format")

      {:name, {:error, error}} ->
        render(conn, :error, error: error)
    end
  end

  defp fetch_name(params) do
    {:name_param, Map.fetch(params, "name")}
  end

  defp fetch_address(params) do
    {:address_param, Map.fetch(params, "address")}
  end

  defp to_address_hash(address_hash_string) do
    {:format, Chain.string_to_address_hash(address_hash_string)}
  end
end
