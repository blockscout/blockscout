defmodule BlockScoutWeb.Account.API.V2.EmailController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, invalid_session_key: [:block_scout_web, :invalid_session_key]

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.Account.API.V2.AuthenticateController
  alias Explorer.Account.Identity
  alias Explorer.{Helper, HttpClient, Repo}
  alias Explorer.ThirdPartyIntegrations.Auth0

  require Logger

  action_fallback(BlockScoutWeb.Account.API.V2.FallbackController)

  plug(:fetch_cookies, signed: [@invalid_session_key])

  def resend_email(conn, _params) do
    with user <- conn.cookies[@invalid_session_key],
         {:auth, false} <- {:auth, is_nil(user)},
         {:email_verified, false} <- {:email_verified, user[:email_verified]},
         {:identity, %Identity{} = identity} <- {:identity, Identity.find_identity(user[:id])},
         {:interval, true} <-
           {:interval,
            Helper.check_time_interval(
              identity.verification_email_sent_at,
              Application.get_env(:explorer, Explorer.Account)[:verification_email_resend_interval]
            )} do
      domain = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:domain]
      api_key = Auth0.get_m2m_jwt()
      headers = [{"Authorization", "Bearer #{api_key}"}, {"Content-Type", "application/json"}]
      url = "https://#{domain}/api/v2/jobs/verification-email"

      body = %{
        "user_id" => user.uid
      }

      case HttpClient.post(url, Jason.encode!(body), headers) do
        {:ok, %{body: _body, status_code: 201}} ->
          identity
          |> Identity.changeset(%{verification_email_sent_at: DateTime.utc_now()})
          |> Repo.account_repo().update()

          conn
          |> configure_session(drop: true)
          |> json(%{message: "Success"})

        other ->
          Logger.error(fn -> ["Error while sending verification email: ", inspect(other)] end)

          conn
          |> put_status(500)
          |> json(%{message: "Unexpected error"})
      end
    end
  end

  @doc """
  Links an email address to the current user's account using OTP verification.

  This function attempts to link a provided email address to the currently
  authenticated user's account. It verifies the provided one-time password (OTP)
  and uses the Auth0 service to associate the email with the user's account.

  The function performs the following steps:
  1. Retrieves the current user's information from the session.
  2. Attempts to link the email to the user's account using the Auth0 service.
  3. If successful, updates the session with the new authentication data.

  ## Parameters
  - `conn`: The `Plug.Conn` struct representing the current connection.
  - `params`: A map containing:
    - `"email"`: The email address to be linked.
    - `"otp"`: The one-time password for verification.

  ## Returns
  - `:error`: If there's an unexpected error during the process.
  - `{:error, any()}`: If there's a specific error during email linking or
    session update. The error details are included.
  - `Conn.t()`: A modified connection struct with updated session information
    if the email is successfully linked.

  ## Notes
  - Errors are handled later in `BlockScoutWeb.Account.API.V2.FallbackController`.
  - This function requires the user to be already authenticated (current user in session).
  - The function will fail if the email is already associated with another account.
  - The OTP must be valid and match the one sent to the provided email.
  - If successful, the function updates the user's Auth0 profile and local session.
  - The session update is handled by the `AuthenticateController.put_auth_to_session/2`
    function, which perform additional operations such as setting cookies or
    rendering user information.
  """
  @spec link_email(Plug.Conn.t(), map()) ::
          :error
          | {:error, any()}
          | Plug.Conn.t()
  def link_email(conn, %{"email" => email, "otp" => otp}) do
    with {:auth, %{} = user} <- {:auth, current_user(conn)},
         {:ok, auth} <- Auth0.link_email(user, email, otp, AccessHelper.conn_to_ip_string(conn)) do
      AuthenticateController.put_auth_to_session(conn, auth)
    end
  end
end
