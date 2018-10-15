defmodule BlockScoutWeb.Admin.SetupController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.AdminRouter.Helpers

  alias BlockScoutWeb.Endpoint
  alias Explorer.Accounts.User.Registration
  alias Explorer.Admin
  alias Phoenix.Token

  @admin_registration_salt "admin-registration"

  plug(:redirect_to_login_if_configured)

  # Step 2: enter new admin credentials
  def configure(conn, %{"state" => state}) do
    case valid_state?(state) do
      true ->
        changeset = Registration.changeset()
        render(conn, "admin_registration.html", changeset: changeset)

      false ->
        render(conn, "verify.html")
    end
  end

  # Step 1: enter recovery key
  def configure(conn, _) do
    render(conn, "verify.html")
  end

  # Step 1: verify recovery token
  def configure_admin(conn, %{"verify" => %{"recovery_key" => key}}) do
    if key == Admin.recovery_key() do
      redirect(conn, to: setup_path(conn, :configure, %{state: generate_secure_token()}))
    else
      render(conn, "verify.html")
    end
  end

  # Step 2: register new admin
  def configure_admin(conn, %{"state" => state, "registration" => registration}) do
    with true <- valid_state?(state),
         {:ok, %{user: user, admin: _admin}} <- Admin.register_owner(registration) do
      conn
      |> put_session(:user_id, user.id)
      |> redirect(to: dashboard_path(conn, :index))
    else
      false ->
        render(conn, "verify.html")

      {:error, changeset} ->
        render(conn, "admin_registration.html", changeset: changeset)
    end
  end

  # Step 1: enter recovery key
  def configure_admin(conn, _) do
    render(conn, "verify.html")
  end

  @doc false
  def generate_secure_token do
    key = Admin.recovery_key()
    Token.sign(Endpoint, @admin_registration_salt, key)
  end

  defp valid_state?(state) do
    # 5 minutes
    max_age_in_seconds = 300
    opts = [max_age: max_age_in_seconds]

    case Token.verify(Endpoint, @admin_registration_salt, state, opts) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp redirect_to_login_if_configured(conn, _) do
    case Admin.owner() do
      {:ok, _} ->
        conn
        |> redirect(to: session_path(conn, :new))
        |> halt()

      _ ->
        conn
    end
  end
end
