defmodule BlockScoutWeb.API.V2.AddressBadgeController do
  require Logger
  use BlockScoutWeb, :controller

  alias Explorer.Chain.Address.{Badge, BadgeToAddress}
  alias Plug.Conn

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def badge(conn, %{"badge_id" => badge_id_string}) do
    with {:ok, body, _conn} <- Conn.read_body(conn, []),
         {:ok, %{"api_key" => provided_api_key}} <- Jason.decode(body),
         {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, provided_api_key},
         {:param, {badge_id, _}} <- {:param, Integer.parse(badge_id_string)},
         badge = Badge.get(badge_id, @api_true),
         false <- is_nil(badge) do
      conn
      |> put_status(200)
      |> render(:badge, %{
        badge: badge
      })
    else
      _ -> {:error, :not_found}
    end
  end

  def badge(_, _), do: {:error, :not_found}

  def create_badge(conn, %{"category" => category, "content" => content} = params) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {:ok, new_badge} <- Badge.create(category, content) do
      conn
      |> put_status(200)
      |> render(:badge, %{
        badge: new_badge,
        status: "created"
      })
    else
      {:error, error} ->
        Logger.error(fn -> ["Address badge creation failed: ", inspect(error)] end)
        {:error, :badge_creation_failed}

      _ ->
        {:api_key, :wrong}
    end
  end

  def create_badge(_, _), do: {:error, :not_found}

  def add_addresses_to_badge(
        conn,
        %{
          "badge_id" => badge_id_string,
          "address_hashes" => address_hashes
        } = params
      )
      when is_list(address_hashes) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {:param, {badge_id, _}} <- {:param, Integer.parse(badge_id_string)},
         {_num_of_inserted, badge_to_address_list} <- BadgeToAddress.create(badge_id, address_hashes) do
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

  def add_addresses_to_badge(_, _), do: {:error, :not_found}

  def remove_addresses_to_badge(
        conn,
        %{
          "badge_id" => badge_id_string,
          "address_hashes" => address_hashes
        } = params
      )
      when is_list(address_hashes) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {:param, {badge_id, _}} <- {:param, Integer.parse(badge_id_string)},
         {_num_of_deleted, badge_to_address_list} <- BadgeToAddress.delete(badge_id, address_hashes) do
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

  def remove_addresses_to_badge(_, _), do: {:error, :not_found}

  def show_badge_addresses(conn, %{"badge_id" => badge_id_string}) do
    with {:ok, body, _conn} <- Conn.read_body(conn, []),
         {:ok, %{"api_key" => provided_api_key}} <- Jason.decode(body),
         {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, provided_api_key},
         {:param, {badge_id, _}} <- {:param, Integer.parse(badge_id_string)} do
      badge_to_address_list = BadgeToAddress.get(badge_id, @api_true)

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

  def show_badge_addresses(_, _), do: {:error, :not_found}

  def update_badge(
        conn,
        %{
          "badge_id" => badge_id_string,
          "category" => category,
          "content" => content
        } = params
      ) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {:param, {badge_id, _}} <- {:param, Integer.parse(badge_id_string)},
         badge = Badge.get(badge_id, @api_true),
         {:ok, new_badge} <- Badge.update(badge, category, content) do
      conn
      |> put_status(200)
      |> render(:badge, %{
        badge: new_badge,
        status: "updated"
      })
    else
      _ -> {:error, :not_found}
    end
  end

  def update_badge(_, _) do
    {:error, :not_found}
  end

  def delete_badge(conn, %{"badge_id" => badge_id_string} = params) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {:param, {badge_id, _}} <- {:param, Integer.parse(badge_id_string)},
         badge = Badge.get(badge_id, @api_true),
         {:ok, deleted_badge} <- Badge.delete(badge) do
      conn
      |> put_status(200)
      |> render(:badge, %{
        badge: deleted_badge,
        status: "deleted"
      })
    else
      _ -> {:error, :not_found}
    end
  end

  def delete_badge(_, _) do
    {:error, :not_found}
  end
end
