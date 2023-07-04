defmodule BlockScoutWeb.Account.Api.V1.EmailController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.Account.Identity
  alias Explorer.Repo
  alias Explorer.ThirdPartyIntegrations.Auth0

  require Logger

  @invalid_session_key Application.compile_env(:block_scout_web, :invalid_session_key)

  action_fallback(BlockScoutWeb.Account.Api.V1.FallbackController)

  plug(:fetch_cookies, signed: [@invalid_session_key])

  def resend_email(conn, _params) do
    with user <- conn.cookies[@invalid_session_key],
         {:auth, false} <- {:auth, is_nil(user)},
         {:email_verified, false} <- {:email_verified, user[:email_verified]},
         {:identity, %Identity{} = identity} <- {:identity, UserFromAuth.find_identity(user[:id])},
         {:interval, true} <- {:interval, check_time_interval(identity.verification_email_sent_at)} do
      domain = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:domain]
      api_key = Auth0.get_m2m_jwt()
      headers = [{"Authorization", "Bearer #{api_key}"}, {"Content-Type", "application/json"}]
      url = "https://#{domain}/api/v2/jobs/verification-email"

      body = %{
        "user_id" => user.uid
      }

      case HTTPoison.post(url, Jason.encode!(body), headers, []) do
        {:ok, %HTTPoison.Response{body: _body, status_code: 201}} ->
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

  def check_time_interval(nil), do: true

  def check_time_interval(sent_at) do
    interval = Application.get_env(:explorer, Explorer.Account)[:resend_interval]
    now = DateTime.utc_now()

    if sent_at
       |> DateTime.add(interval, :millisecond)
       |> DateTime.compare(now) != :gt do
      true
    else
      sent_at
      |> DateTime.add(interval, :millisecond)
      |> DateTime.diff(now, :second)
    end
  end
end
