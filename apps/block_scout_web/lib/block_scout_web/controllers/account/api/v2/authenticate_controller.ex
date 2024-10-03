defmodule BlockScoutWeb.Account.Api.V2.AuthenticateController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  alias BlockScoutWeb.{AccessHelper, CaptchaHelper}
  alias BlockScoutWeb.Account.Api.V2.UserView
  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Account.Identity
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.ThirdPartyIntegrations.Auth0
  alias Plug.Conn

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
    with {:recaptcha, true} <- {:recaptcha, CaptchaHelper.recaptcha_passed?(params)} do
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

  def confirm_otp(conn, %{"email" => email, "otp" => otp}) do
    with {:ok, auth} <- Auth0.confirm_otp_and_get_auth(email, otp) do
      put_auth_to_session(conn, auth)
    end
  end

  def siwe_message(conn, %{"address" => address}) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address)},
         {:ok, message} <- Auth0.generate_siwe_message(Address.checksum(address_hash)) do
      conn |> put_status(200) |> json(%{siwe_message: message})
    end
  end

  def authenticate_via_wallet(conn, %{"message" => message, "signature" => signature}) do
    with {:ok, auth} <- Auth0.get_auth_with_web3(message, signature) do
      put_auth_to_session(conn, auth)
    end
  end

  @spec put_auth_to_session(Conn.t(), Ueberauth.Auth.t()) :: {:error, any()} | Conn.t()
  def put_auth_to_session(conn, auth) do
    with {:ok, %{id: uid} = session} <- Identity.find_or_create(auth),
         {:identity, %Identity{} = identity} <- {:identity, Identity.find_identity(uid)} do
      conn
      |> Conn.fetch_session()
      |> put_session(:current_user, session)
      |> delete_resp_cookie(Application.get_env(:block_scout_web, :invalid_session_key))
      |> put_status(200)
      |> put_view(UserView)
      |> render(:user_info, %{identity: identity |> Identity.put_session_info(session)})
    end
  end
end
