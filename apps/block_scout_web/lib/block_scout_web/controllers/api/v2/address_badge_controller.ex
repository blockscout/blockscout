defmodule BlockScoutWeb.API.V2.AddressBadgeController do
  require Logger
  use BlockScoutWeb, :controller

  alias Explorer.Chain.Address.ScamBadgeToAddress
  alias Plug.Conn

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def assign_badge_to_address(
        conn,
        %{
          "address_hashes" => address_hashes
        } = params
      )
      when is_list(address_hashes) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {_num_of_inserted, badge_to_address_list} <- ScamBadgeToAddress.add(address_hashes) do
      conn
      |> put_status(200)
      |> render(:badge_to_address, %{
        badge_to_address_list: badge_to_address_list,
        status: if(Enum.empty?(badge_to_address_list), do: "update skipped", else: "added")
      })
    else
      {:error, error} ->
        Logger.error(fn -> ["Badge addresses addition failed: ", inspect(error)] end)
        {:error, :badge_creation_failed}

      _ ->
        {:api_key, :wrong}
    end
  end

  def assign_badge_to_address(_, _), do: {:error, :not_found}

  def unassign_badge_from_address(
        conn,
        %{
          "address_hashes" => address_hashes
        } = params
      )
      when is_list(address_hashes) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {_num_of_deleted, badge_to_address_list} <- ScamBadgeToAddress.delete(address_hashes) do
      conn
      |> put_status(200)
      |> render(:badge_to_address, %{
        badge_to_address_list: badge_to_address_list,
        status: if(Enum.empty?(badge_to_address_list), do: "update skipped", else: "removed")
      })
    else
      {:error, error} ->
        Logger.error(fn -> ["Badge addresses addition failed: ", inspect(error)] end)
        {:error, :badge_creation_failed}

      _ ->
        {:api_key, :wrong}
    end
  end

  def unassign_badge_from_address(_, _), do: {:error, :not_found}

  def show_badge_addresses(conn, _) do
    with {:ok, body, _conn} <- Conn.read_body(conn, []),
         {:ok, %{"api_key" => provided_api_key}} <- Jason.decode(body),
         {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, provided_api_key} do
      badge_to_address_list = ScamBadgeToAddress.get(@api_true)

      conn
      |> put_status(200)
      |> render(:badge_to_address, %{
        badge_to_address_list: badge_to_address_list
      })
    else
      _ ->
        {:error, :not_found}
    end
  end
end
