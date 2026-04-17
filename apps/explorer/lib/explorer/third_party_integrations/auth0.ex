defmodule Explorer.ThirdPartyIntegrations.Auth0 do
  @moduledoc """
  Auth0 Management REST API client for user management.
  """
  require Logger

  alias Explorer.Account.{Authentication, Identity}
  alias Explorer.{Helper, HttpClient}
  alias Explorer.ThirdPartyIntegrations.Auth0.Internal
  alias Explorer.ThirdPartyIntegrations.Dynamic
  alias Ueberauth.Strategy.Auth0.OAuth

  @behaviour Authentication

  @json_content_type [{"Content-type", "application/json"}]

  @spec enabled? :: boolean()
  def enabled? do
    Application.get_env(:ueberauth, OAuth)[:domain] not in [nil, ""] and
      !Application.get_env(:explorer, Dynamic)[:enabled]
  end

  @doc """
  Retrieves a machine-to-machine JWT for interacting with the Auth0 Management API.

  This function first attempts to access a cached token. If no cached token is
  found, it requests a new token from Auth0 and caches it for future use.

  ## Returns
  - `nil` if token retrieval fails
  - `String.t()` containing the JWT if successful
  """
  @spec get_m2m_jwt() :: nil | String.t()
  def get_m2m_jwt do
    get_m2m_jwt_inner(Redix.command(:redix, ["GET", m2m_jwt_key()]))
  end

  defp get_m2m_jwt_inner({:ok, token}) when not is_nil(token), do: token

  defp get_m2m_jwt_inner(_) do
    config = Application.get_env(:ueberauth, OAuth)

    body = %{
      "client_id" => config[:client_id],
      "client_secret" => config[:client_secret],
      "audience" => "https://#{config[:domain]}/api/v2/",
      "grant_type" => "client_credentials"
    }

    case HttpClient.post("https://#{config[:domain]}/oauth/token", Jason.encode!(body), @json_content_type) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode!(body) do
          %{"access_token" => token, "expires_in" => ttl} ->
            cache_token(token, ttl - 1)

          _ ->
            nil
        end

      error ->
        Logger.error("Error while fetching Auth0 M2M JWT: #{inspect(error)}")
        nil
    end
  end

  defp cache_token(token, ttl) do
    Redix.command(:redix, ["SET", m2m_jwt_key(), token, "EX", ttl])
    token
  end

  defp m2m_jwt_key, do: Helper.redis_key(Internal.redis_key())

  @doc """
  Sends a one-time password (OTP) for linking an email to an existing account.

  This function checks if the email is already associated with an account before
  sending the OTP. If the email is already in use, it returns an error.

  ## Parameters
  - `email`: The email address to send the OTP to
  - `ip`: The IP address of the requester

  ## Returns
  - `:ok` if the OTP was sent successfully
  - `{:error, String.t()}` error with the description
  - `:error` if there was an unexpected error
  - `{:format, :email}` if the email format is invalid
  """
  @impl Authentication
  def send_otp_for_linking(email, ip) do
    case Internal.find_users_by_email(email) do
      {:ok, []} ->
        Internal.send_otp(email, ip)

      {:ok, users} when is_list(users) and users !== [] ->
        {:error, "Account with this email already exists"}

      error ->
        error
    end
  end

  @doc """
  Sends a one-time password (OTP) to the specified email address.

  This function checks if the email is associated with an existing user before
  sending the OTP. If the user exists, it checks time interval and sends the OTP
  or reports when the user can request a new OTP.

  ## Parameters
  - `email`: The email address to send the OTP to
  - `ip`: The IP address of the requester

  ## Returns
  - `:ok` if the OTP was sent successfully
  - `:error` if there was an unexpected error
  - `{:interval, integer()}` if the user need to wait before sending the OTP
  """
  @impl Authentication
  def send_otp(email, ip) do
    case Internal.find_users_by_email(email) do
      {:ok, []} ->
        Internal.send_otp(email, ip)

      {:ok, [user | _]} ->
        Internal.handle_existing_user(user, email, ip)

      error ->
        error
    end
  end

  @doc """
  Links an email to an existing user account using a one-time password (OTP).

  This function verifies the OTP, creates a new identity for the email, and links
  it to the existing user account.

  ## Parameters
  - `primary_user_id`: The ID of the existing user account
  - `email`: The email address to be linked
  - `otp`: The one-time password for verification
  - `ip`: The IP address of the requester

  ## Returns
  - `{:ok, Auth.t()}` if the email was successfully linked
  - `{:error, String.t()}` error with the description
  - `:error` if there was an unexpected error
  """
  @impl Authentication
  def link_email(%{uid: user_id_without_email, email: nil}, email, otp, ip) do
    case Internal.find_users_by_email(email) do
      {:ok, []} ->
        with {:ok, token} <- Internal.confirm_otp(email, otp, ip),
             {:ok, %{"sub" => user_id_with_email}} <- Internal.get_user_from_token(token),
             {:ok, user} <- Internal.link_email(user_id_without_email, user_id_with_email, email) do
          {:ok, Internal.create_auth(user)}
        end

      {:ok, users} when is_list(users) ->
        {:error, "Account with this email already exists"}

      error ->
        error
    end
  end

  def link_email(_account_with_email, _, _, _), do: {:error, "This account already has an email"}

  @doc """
  Confirms a one-time password (OTP) and retrieves authentication information.

  This function verifies the OTP for the given email and returns the
  authentication information if successful.

  ## Parameters
  - `email`: The email address associated with the OTP
  - `otp`: The one-time password to be confirmed
  - `ip`: The IP address of the requester

  ## Returns
  - `{:ok, Auth.t()}` if the OTP is confirmed and authentication is successful
  - `{:error, String.t()}` error with the description
  - `:error` if there was an unexpected error
  """
  @impl Authentication
  def confirm_otp_and_get_auth(email, otp, ip) do
    with {:ok, token} <- Internal.confirm_otp(email, otp, ip),
         {:ok, %{"sub" => user_id} = user} <- Internal.get_user_from_token(token),
         {:search, _user_from_token, {:ok, user}} <- {:search, user, Internal.get_user_by_id(user_id)},
         {:ok, user} <- Internal.process_email_user(user) do
      {:ok, Internal.create_auth(user)}
    else
      # newly created user, sometimes just created user with otp does not appear in the search
      {:search, %{"sub" => _user_id} = user_from_token, {:error, "User not found"}} ->
        Internal.handle_not_found_just_created_email_user(user_from_token)

      err ->
        err
    end
  end

  @doc """
  Updates the session with the user's address hash.

  This function checks if the session already has an address hash. If not, it
  retrieves the user's information and adds the address hash to the session.

  ## Parameters
  - `session`: The current session map (Identity.session())

  ## Returns
  - `{:old, Identity.session()}` if the session already has an address hash
  - `{:new, Identity.session()}` if the address hash was added to the session
  """
  @spec update_session_with_address_hash(Identity.session()) :: {:old, Identity.session()} | {:new, Identity.session()}
  def update_session_with_address_hash(session),
    do: Internal.update_session_with_address_hash(session)

  @doc """
  Links a web3 wallet address to an existing user account.

  Checks that no other account is already associated with the given address,
  then updates the user's Auth0 profile with the address and returns updated
  authentication information.

  ## Parameters
  - `user_id`: The Auth0 user ID of the account to update.
  - `address`: The web3 wallet address to associate with the account.

  ## Returns
  - `{:ok, Auth.t()}` if the address was successfully linked.
  - `{:error, "Account with this address already exists"}` if another account
    is already using the given address.
  - `{:error, String.t()}` if a known error occurs.
  - `:error` if an unexpected error occurs.
  """
  @impl Authentication
  def link_address(user_id, address) do
    with {:user, {:ok, []}} <- {:user, Internal.find_users_by_web3_address(address)},
         {:ok, user} <- Internal.update_user_with_web3_address(user_id, address) do
      {:ok, Internal.create_auth(user)}
    else
      {:user, {:ok, _users}} ->
        {:error, "Account with this address already exists"}

      {:user, error} ->
        error

      other ->
        other
    end
  end

  @doc """
  Finds an existing user by web3 wallet address or creates a new one.

  Delegates to the Auth0 backend to locate a user whose profile contains the
  given address. If no user is found, a new Auth0 account is created using the
  address as the username and the cryptographic signature as the password.
  On success, returns authentication information for the resolved user.

  ## Parameters
  - `address`: The web3 wallet address used to identify or create the user.
  - `signature`: The cryptographic signature used as the password when creating
    a new user.

  ## Returns
  - `{:ok, Auth.t()}` if the user was found or successfully created.
  - `{:error, String.t()}` if a known error occurs.
  - `:error` if an unexpected error occurs.
  """
  @impl Authentication
  def find_or_create_web3_user(address, signature) do
    with {:ok, user} <- Internal.process_web3_user(address, signature) do
      {:ok, Internal.create_auth(user)}
    end
  end
end
