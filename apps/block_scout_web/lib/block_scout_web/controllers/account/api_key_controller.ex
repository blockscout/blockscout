defmodule BlockScoutWeb.Account.ApiKeyController do
  use BlockScoutWeb, :controller

  alias Explorer.Account.Api.Key, as: ApiKey

  import BlockScoutWeb.Account.AuthController, only: [authenticate!: 1]

  def new(conn, _params) do
    authenticate!(conn)

    render(conn, "form.html", method: :create, api_key: empty_api_key())
  end

  def create(conn, %{"key" => api_key}) do
    current_user = authenticate!(conn)

    case ApiKey.create_api_key_changeset_and_insert(%ApiKey{}, %{name: api_key["name"], identity_id: current_user.id}) do
      {:ok, _} ->
        redirect(conn, to: api_key_path(conn, :index))

      {:error, invalid_api_key} ->
        render(conn, "form.html", method: :create, api_key: invalid_api_key)
    end
  end

  def create(conn, _) do
    redirect(conn, to: api_key_path(conn, :index))
  end

  def index(conn, _params) do
    current_user = authenticate!(conn)

    render(conn, "index.html", api_keys: ApiKey.get_api_keys_by_identity_id(current_user.id))
  end

  def edit(conn, %{"id" => api_key}) do
    current_user = authenticate!(conn)

    case ApiKey.api_key_by_value_and_identity_id(api_key, current_user.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(BlockScoutWeb.PageNotFoundView)
        |> render("index.html", token: nil)

      %ApiKey{} = api_key ->
        render(conn, "form.html", method: :update, api_key: ApiKey.changeset(api_key))
    end
  end

  def update(conn, %{"id" => api_key, "key" => %{"value" => api_key, "name" => name}}) do
    current_user = authenticate!(conn)

    ApiKey.update_api_key(%{value: api_key, identity_id: current_user.id, name: name})

    redirect(conn, to: api_key_path(conn, :index))
  end

  def delete(conn, %{"id" => api_key}) do
    current_user = authenticate!(conn)

    ApiKey.delete_api_key(current_user.id, api_key)

    redirect(conn, to: api_key_path(conn, :index))
  end

  defp empty_api_key, do: ApiKey.changeset()
end
