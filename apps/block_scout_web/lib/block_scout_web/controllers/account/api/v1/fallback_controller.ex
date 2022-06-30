defmodule BlockScoutWeb.Account.Api.V1.FallbackController do
  use Phoenix.Controller

  alias BlockScoutWeb.Account.Api.V1.UserView
  alias Ecto.Changeset

  def call(conn, {:identity, _}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:error, %{message: "User not found"})
  end

  def call(conn, {:watchlist, _}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:error, %{message: "Watchlist not found"})
  end

  def call(conn, {:error, %{reason: :item_not_found}}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:error, %{message: "Item not found"})
  end

  def call(conn, {:error, %Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(UserView)
    |> render(:changeset_errors, changeset: changeset)
  end

  def call(conn, {:create_tag, {:error, message}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(UserView)
    |> render(:error, %{message: message})
  end

  def call(conn, {:watchlist_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:error, %{message: "Watchlist address not found"})
  end

  def call(conn, {:tag_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:error, %{message: "Tag not found"})
  end

  def call(conn, {:api_key_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:error, %{message: "Api key not found"})
  end

  def call(conn, {:custom_abi_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:error, %{message: "Custom ABI not found"})
  end
end
