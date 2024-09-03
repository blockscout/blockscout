defmodule BlockScoutWeb.Account.Api.V2.AuthenticateController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.Account.AuthController
  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Account.Identity
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.CSVExport.Helper, as: CSVHelper
  alias Explorer.ThirdPartyIntegrations.Auth0
  alias Plug.{Conn, CSRFProtection}

  action_fallback(BlockScoutWeb.Account.Api.V2.FallbackController)

  def authenticate_get(conn, params) do
    authenticate(conn, params)
  end

  def authenticate_post(conn, params) do
    authenticate(conn, params)
  end

  defp authenticate(conn, params) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, params["api_key"]},
         {:auth, %{id: uid} = current_user} <- {:auth, current_user(conn)},
         {:identity, %Identity{}} <- {:identity, Identity.find_identity(uid)} do
      conn
      |> put_status(200)
      |> json(current_user)
    end
  end

  def send_otp(conn, %{"email" => email} = params) do
    with {:recaptcha, true} <-
           {:recaptcha,
            Application.get_env(:block_scout_web, :recaptcha)[:is_disabled] ||
              CSVHelper.captcha_helper().recaptcha_passed?(params["recaptcha_response"])} do
      case conn |> Conn.fetch_session() |> current_user() do
        nil ->
          with :ok <- Auth0.send_otp(email, AccessHelper.conn_to_ip_string(conn)) do
            conn |> put_status(200) |> json(%{message: "Success"})
          end

        %{email: ^email} ->
          conn |> put_status(500) |> put_view(ApiView) |> render(:message, %{message: "Already linked to this account"})

        %{} ->
          with :ok <- Auth0.send_otp_for_linking(email, AccessHelper.conn_to_ip_string(conn)) do
            conn |> put_status(200) |> json(%{message: "Success"})
          end
      end
    end
  end

  def confirm_otp(conn, %{"email" => email, "otp" => otp} = params) do
    with {:ok, auth} <- Auth0.confirm_otp_and_get_auth(email, otp) do
      put_auth_to_session(conn, params, auth)
    end
  end

  def siwe_message(conn, %{"address" => address}) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address)},
         {:ok, message} <- Auth0.generate_siwe_message(Address.checksum(address_hash)) do
      conn |> put_status(200) |> json(%{siwe_message: message})
    end
  end

  def authenticate_via_wallet(conn, %{"message" => message, "signature" => signature} = params) do
    with {:ok, auth} <- Auth0.get_auth_with_web3(message, signature) do
      put_auth_to_session(conn, params, auth)
    end
  end

  @spec put_auth_to_session(any(), any(), Ueberauth.Auth.t()) :: {:error, any()} | Plug.Conn.t()
  def put_auth_to_session(conn, params, auth) do
    with {:ok, user} <- Identity.find_or_create(auth) do
      CSRFProtection.get_csrf_token()

      conn
      |> Conn.fetch_session()
      |> put_session(:current_user, user)
      |> delete_resp_cookie(Application.get_env(:block_scout_web, :invalid_session_key))
      |> redirect(to: AuthController.redirect_path(params["path"]))
    end
  end
end
