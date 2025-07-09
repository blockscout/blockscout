defmodule BlockScoutWeb.Account.API.V2.AuthenticateController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.Account.API.V2.UserView
  alias BlockScoutWeb.API.V2.ApiView
  alias Explorer.Account.Identity
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.ThirdPartyIntegrations.Auth0
  alias Plug.Conn

  action_fallback(BlockScoutWeb.Account.API.V2.FallbackController)

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

  @doc """
  Sends a one-time password (OTP) to the specified email address.

  This function handles the process of sending an OTP to a given email address,
  with different behaviors based on the current user's authentication status
  and the relationship between the provided email and existing accounts.

  The function first verifies the reCAPTCHA response to prevent abuse. Then,
  it checks the current user's status and proceeds accordingly:

  1. If no user is logged in, it sends an OTP for a new account.
  2. If a user is logged in and the email matches their account, it returns an error.
  3. If a user is logged in but the email doesn't match, it checks if there is already
  a user with such email and sends an OTP for linking if there is no such user.

  ## Parameters
  - `conn`: The `Plug.Conn` struct representing the current connection.
  - `params`: A map containing:
    - `"email"`: The email address to which the OTP should be sent.
    - `"recaptcha_v3_response"` or `"recaptcha_response"`: The reCAPTCHA response token.

  ## Returns
  - `:error`: If there's an unexpected error during the process.
  - `{:error, String.t()}`: If there's a specific error (e.g., email already linked).
  - `{:interval, integer()}`: If an OTP was recently sent and the cooldown period hasn't elapsed.
  - `{:recaptcha, false}`: If the reCAPTCHA verification fails.
  - `Plug.Conn.t()`: A modified connection struct with a 200 status and success message
    if the OTP is successfully sent.

  ## Notes
  - Errors are handled later in `BlockScoutWeb.Account.API.V2.FallbackController`.
  - The function uses the client's IP address for rate limiting and abuse prevention.
  - It handles both logged-in and non-logged-in user scenarios.
  """
  @spec send_otp(Conn.t(), map()) ::
          :error
          | {:error, String.t()}
          | {:interval, integer()}
          | Conn.t()
  def send_otp(conn, %{"email" => email}) do
    case conn |> Conn.fetch_session() |> current_user() do
      nil ->
        with :ok <- Auth0.send_otp(email, AccessHelper.conn_to_ip_string(conn)) do
          conn |> put_status(200) |> json(%{message: "Success"})
        end

      %{email: nil} ->
        with :ok <- Auth0.send_otp_for_linking(email, AccessHelper.conn_to_ip_string(conn)) do
          conn |> put_status(200) |> json(%{message: "Success"})
        end

      %{} ->
        conn
        |> put_status(500)
        |> put_view(ApiView)
        |> render(:message, %{message: "This account already has an email"})
    end
  end

  @doc """
  Confirms a one-time password (OTP) for a given email and updates the session.

  This function verifies the OTP provided for a specific email address. If the
  OTP is valid, it retrieves the authentication information and updates the
  user's session accordingly.

  The function performs the following steps:
  1. Confirms the OTP with Auth0 and retrieves the authentication information.
  2. If successful, updates the session with the new authentication data.

  ## Parameters
  - `conn`: The `Plug.Conn` struct representing the current connection.
  - `params`: A map containing:
    - `"email"`: The email address associated with the OTP.
    - `"otp"`: The one-time password to be confirmed.

  ## Returns
  - `:error`: If there's an unexpected error during the process.
  - `{:error, any()}`: If there's a specific error during OTP confirmation or
    session update. The error details are included.
  - `Conn.t()`: A modified connection struct with updated session information
    if the OTP is successfully confirmed.

  ## Notes
  - Errors are handled later in `BlockScoutWeb.Account.API.V2.FallbackController`.
  - This function relies on the Auth0 service to confirm the OTP and retrieve
    the authentication information.
  - The function handles both existing and newly created users.
  - For newly created users, it may create a new authentication record if the
    user is not immediately found in the search after OTP confirmation.
  - The session update is handled by the `put_auth_to_session/2` function, which
    perform additional operations such as setting cookies or rendering user
    information.
  """
  @spec confirm_otp(Conn.t(), map()) :: :error | {:error, any()} | Conn.t()
  def confirm_otp(conn, %{"email" => email, "otp" => otp}) do
    with {:ok, auth} <- Auth0.confirm_otp_and_get_auth(email, otp, AccessHelper.conn_to_ip_string(conn)) do
      put_auth_to_session(conn, auth)
    end
  end

  @doc """
  Generates a Sign-In with Ethereum (SIWE) message for a given Ethereum address.

  This function takes an Ethereum address, validates its format, converts it to
  its checksum representation, and then generates a SIWE message. The generated
  message is returned as part of a JSON response.

  The function performs the following steps:
  1. Validates and converts the input address string to an address hash.
  2. Converts the address hash to its checksum representation.
  3. Generates a SIWE message using the checksum address.
  4. Returns the generated message in a JSON response.

  ## Parameters
  - `conn`: The `Plug.Conn` struct representing the current connection.
  - `params`: A map containing:
    - `"address"`: The Ethereum address as a string, starting with "0x".

  ## Returns
  - `{:error, String.t()}`: If there's an error during the SIWE message generation process.
  - `{:format, :error}`: If the provided address string is not in a valid format.
  - `Conn.t()`: A modified connection struct with a 200 status and a JSON body
    containing the generated SIWE message if successful.

  ## Notes
  - Errors are handled later in `BlockScoutWeb.Account.API.V2.FallbackController`.
  - The address is converted to its checksum format before generating the SIWE message.
  - The generated SIWE message includes:
    - The domain and URI of the application.
    - A statement for signing in.
    - The chain ID of the current network.
    - A nonce for security.
    - Issuance and expiration timestamps.
  - The nonce is cached for the address to prevent replay attacks.
  - The SIWE message expires after 300 seconds from generation.
  """
  @spec siwe_message(Conn.t(), map()) :: {:error, String.t()} | {:format, :error} | Conn.t()
  def siwe_message(conn, %{"address" => address}) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address)},
         {:ok, message} <- Auth0.generate_siwe_message(Address.checksum(address_hash)) do
      conn |> put_status(200) |> json(%{siwe_message: message})
    end
  end

  @doc """
  Authenticates a user via their Ethereum wallet using a signed message.

  This function verifies a signed Ethereum message to authenticate a user. It uses
  the Sign-In with Ethereum (SIWE) protocol to validate the signature and retrieve
  or create the user's authentication information.

  The function performs the following steps:
  1. Verifies the provided message and signature.
  2. If successful, updates the session with the new authentication data.

  ## Parameters
  - `conn`: The `Plug.Conn` struct representing the current connection.
  - `params`: A map containing:
    - `"message"`: The SIWE message that was signed.
    - `"signature"`: The signature of the message.

  ## Returns
  - `:error`: If there's an unexpected error during the process.
  - `{:error, any()}`: If there's a specific error during authentication or
    session update. The error details are included.
  - `Conn.t()`: A modified connection struct with updated session information
    if the authentication is successful.

  ## Notes
  - Errors are handled later in `BlockScoutWeb.Account.API.V2.FallbackController`.
  - The function verifies the nonce in the message to prevent replay attacks.
  - If the user doesn't exist, a new Web3 user is created based on the Ethereum address.
  - The nonce is deleted after successful verification to prevent reuse.
  - The session update is handled by the `put_auth_to_session/2` function, which
    perform additional operations such as setting cookies or rendering user
    information.
  """
  @spec authenticate_via_wallet(Conn.t(), map()) :: :error | {:error, any()} | Conn.t()
  def authenticate_via_wallet(conn, %{"message" => message, "signature" => signature}) do
    with {:ok, auth} <- Auth0.get_auth_with_web3(message, signature) do
      put_auth_to_session(conn, auth)
    end
  end

  @doc """
  Updates the session with authentication information and renders user info.

  This function takes the authentication data, creates or retrieves the user's
  identity, updates the session, and renders the user information. It performs
  the following steps:

  1. Finds or creates a user session based on the authentication data.
  2. Retrieves the user's identity using the session ID.
  3. Updates the connection's session with the current user information.
  4. Renders the user information view.

  ## Parameters
  - `conn`: The `Plug.Conn` struct representing the current connection.
  - `auth`: A `Ueberauth.Auth.t()` struct containing the authentication information.

  ## Returns
  - `{:error, any()}`: If there's an error during the process of finding/creating
    the user session or retrieving the user's identity.
  - `Conn.t()`: A modified connection struct with updated session information
    and rendered user info if successful.

  ## Notes
  - Errors are handled later in `BlockScoutWeb.Account.API.V2.FallbackController`.
  - This function relies on the `Identity` module to handle user identity operations.
  - It updates the session with the current user information.
  - The function sets the HTTP status to 200 on successful authentication.
  - It uses the `UserView` to render the user information.
  - The rendered user information includes session data (name, nickname, and
    optionally address_hash) merged with the identity data.
  """
  @spec put_auth_to_session(Conn.t(), Ueberauth.Auth.t()) :: {:error, any()} | Conn.t()
  def put_auth_to_session(conn, auth) do
    with {:ok, %{id: uid} = session} <- Identity.find_or_create(auth),
         {:identity, %Identity{} = identity} <- {:identity, Identity.find_identity(uid)} do
      conn
      |> Conn.fetch_session()
      |> configure_session(renew: true)
      |> put_session(:current_user, session)
      |> delete_resp_cookie(Application.get_env(:block_scout_web, :invalid_session_key))
      |> put_status(200)
      |> put_view(UserView)
      |> render(:user_info, %{identity: identity |> Identity.put_session_info(session)})
    end
  end
end
