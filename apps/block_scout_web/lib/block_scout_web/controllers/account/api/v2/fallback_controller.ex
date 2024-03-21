defmodule BlockScoutWeb.Account.Api.V2.FallbackController do
  use Phoenix.Controller

  alias BlockScoutWeb.Account.Api.V2.UserView
  alias Ecto.Changeset

  def call(conn, {:identity, _}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "User not found"})
  end

  def call(conn, {:watchlist, _}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "Watchlist not found"})
  end

  def call(conn, {:error, %{reason: :item_not_found}}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "Item not found"})
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
    |> render(:message, %{message: message})
  end

  def call(conn, {:watchlist_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "Watchlist address not found"})
  end

  def call(conn, {:tag_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "Tag not found"})
  end

  def call(conn, {:api_key_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "Api key not found"})
  end

  def call(conn, {:custom_abi_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "Custom ABI not found"})
  end

  def call(conn, {:public_tag_delete, false}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "Error"})
  end

  def call(conn, {:auth, _}) do
    current_user = get_session(conn, :current_user)

    conn
    |> put_status(if(current_user, do: :forbidden, else: :unauthorized))
    |> put_view(UserView)
    |> json(unauthorized_error(current_user))
  end

  def call(conn, {:api_key, _}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(UserView)
    |> render(:message, %{message: "Wrong API key"})
  end

  def call(conn, {:sensitive_endpoints_api_key, _}) do
    conn
    |> put_status(:forbidden)
    |> put_view(UserView)
    |> render(:message, %{message: "API key not configured on the server"})
  end

  def call(conn, {:email_verified, _}) do
    conn
    |> put_status(:not_found)
    |> put_view(UserView)
    |> render(:message, %{message: "Your email address already verified"})
  end

  def call(conn, {:interval, remain}) do
    conn
    |> put_status(:too_many_requests)
    |> put_view(UserView)
    |> json(%{message: "Email resend is available in #{remain} seconds.", seconds_before_next_resend: remain})
  end

  defp unauthorized_error(%{email_verified: false, email: email}) do
    %{message: "Unverified email", email: email}
  end

  defp unauthorized_error(_) do
    %{message: "Unauthorized"}
  end
end
