defmodule BlockScoutWeb.Account.Api.V1.EmailController do
  use BlockScoutWeb, :controller

  alias Explorer.ThirdPartyIntegrations.Auth0

  require Logger

  action_fallback(BlockScoutWeb.Account.Api.V1.FallbackController)

  def resend_email(conn, _params) do
    with user <- get_session(conn, :current_user),
         {:auth, false} <- {:auth, is_nil(user)},
         {:email_verified, false} <- {:email_verified, user[:email_verified]} do
      domain = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:domain]
      api_key = Auth0.get_m2m_jwt()
      headers = [{"Authorization", "Bearer #{api_key}"}, {"Content-Type", "application/json"}]
      url = "https://#{domain}/api/v2/jobs/verification-email"

      body = %{
        "user_id" => user.uid
      }

      case HTTPoison.post(url, Jason.encode!(body), headers, []) do
        {:ok, %HTTPoison.Response{body: _body, status_code: 201}} ->
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
end
