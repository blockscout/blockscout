defmodule Explorer.ThirdPartyIntegrations.Auth0 do
  @moduledoc """
    Module for fetching jwt Auth0 Management API (https://auth0.com/docs/api/management/v2) jwt
  """
  require Logger

  alias Explorer.Account.Identity
  alias Explorer.{Account, Helper, HttpClient}
  alias Explorer.ThirdPartyIntegrations.Auth0.Internal
  alias Ueberauth.Auth
  alias Ueberauth.Strategy.Auth0.OAuth

  @request_siwe_message "Request Sign in with Ethereum message via /api/account/v2/siwe_message"
  @wrong_nonce "Wrong nonce in message"
  @misconfiguration_detected "Misconfiguration detected, please contact support."
  @json_content_type [{"Content-type", "application/json"}]

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
    get_m2m_jwt_inner(Redix.command(:redix, ["GET", Internal.redis_key()]))
  end

  def get_m2m_jwt_inner({:ok, token}) when not is_nil(token), do: token

  def get_m2m_jwt_inner(_) do
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

      _ ->
        nil
    end
  end

  @doc """
  Generates a key from chain_id and cookie hash for storing in Redis.

  This function combines the chain_id (if available) with the provided hash to
  create a unique key for Redis storage.

  ## Parameters
  - `hash`: The hash to be combined with the chain_id

  ## Returns
  - `String.t()` representing the generated key
  """
  @spec cookie_key(binary) :: String.t()
  def cookie_key(hash) do
    chain_id = Application.get_env(:block_scout_web, :chain_id)

    if chain_id do
      chain_id <> "_" <> hash
    else
      hash
    end
  end

  defp cache_token(token, ttl) do
    Redix.command(:redix, ["SET", Internal.redis_key(), token, "EX", ttl])
    token
  end

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
  """
  @spec send_otp_for_linking(String.t(), String.t()) :: :error | :ok | {:error, String.t()}
  def send_otp_for_linking(email, ip) do
    case Internal.find_users_by_email(email) do
      {:ok, []} ->
        Internal.send_otp(email, ip)

      {:ok, users} when is_list(users) and length(users) > 0 ->
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
  @spec send_otp(String.t(), String.t()) :: :error | :ok | {:interval, integer()}
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
  @spec link_email(Identity.session(), String.t(), String.t(), String.t()) ::
          :error | {:ok, Auth.t()} | {:error, String.t()}
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
  @spec confirm_otp_and_get_auth(String.t(), String.t(), String.t()) :: :error | {:error, String.t()} | {:ok, Auth.t()}
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
  Generates a Sign-In with Ethereum (SIWE) message for the given address.

  This function creates a SIWE message with a unique nonce, caches the nonce,
  and returns the formatted message string.

  ## Parameters
  - `address`: The Ethereum address for which to generate the SIWE message

  ## Returns
  - `{:ok, String.t()}` containing the generated SIWE message
  - `{:error, String.t()}` error with the description
  """
  @spec generate_siwe_message(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_siwe_message(address) do
    nonce = Siwe.generate_nonce()
    {int_chain_id, _} = Integer.parse(Application.get_env(:block_scout_web, :chain_id))

    message = %Siwe.Message{
      domain: Helper.get_app_host(),
      address: address,
      statement: Application.get_env(:explorer, Account)[:siwe_message],
      uri:
        Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:scheme] <>
          "://" <> Helper.get_app_host(),
      version: "1",
      chain_id: int_chain_id,
      nonce: nonce,
      issued_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      expiration_time: DateTime.utc_now() |> DateTime.add(300, :second) |> DateTime.to_iso8601()
    }

    with {:cache, {:ok, _nonce}} <- {:cache, Internal.cache_nonce_for_address(nonce, address)},
         {:message, {:ok, message}} <- {:message, Siwe.to_str(message)} do
      {:ok, message}
    else
      {:cache, {:error, error}} ->
        Logger.error("Error while caching nonce: #{inspect(error)}")
        {:error, @misconfiguration_detected}

      {:message, {:error, error}} ->
        Logger.error("Error while generating Sign in with Ethereum Message: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Links an Ethereum address to an existing user account.

  This function verifies the SIWE message and signature, checks for existing
  users with the same address, and updates the user's account with the new
  address.

  ## Parameters
  - `user_id`: The ID of the existing user account
  - `message`: The SIWE message
  - `signature`: The signature of the SIWE message

  ## Returns
  - `{:ok, Auth.t()}` if the address was successfully linked
  - `{:error, String.t()}` error with the description
  - `:error` if there was an unexpected error
  """
  @spec link_address(String.t(), String.t(), String.t()) :: :error | {:error, String.t()} | {:ok, Auth.t()}
  def link_address(user_id, message, signature) do
    with {:signature, {:ok, %{nonce: nonce, address: address}}} <-
           {:signature, message |> String.trim() |> Siwe.parse_if_valid(signature)},
         {:nonce, {:ok, ^nonce}} <- {:nonce, Internal.get_nonce_for_address(address)},
         {:user, {:ok, []}} <- {:user, Internal.find_users_by_web3_address(address)},
         {:ok, user} <- Internal.update_user_with_web3_address(user_id, address) do
      {:ok, Internal.create_auth(user)}
    else
      {:nonce, {:ok, _}} ->
        {:error, @wrong_nonce}

      {:nonce, _} ->
        {:error, @request_siwe_message}

      {:signature, error} ->
        error

      {:user, {:ok, _users}} ->
        {:error, "Account with this address already exists"}

      {:user, error} ->
        error

      other ->
        other
    end
  end

  @doc """
  Authenticates a user using a Sign-In with Ethereum (SIWE) message and signature.

  This function verifies the SIWE message and signature, finds or creates a user
  associated with the Ethereum address, and returns the authentication information.

  ## Parameters
  - `message`: The SIWE message
  - `signature`: The signature of the SIWE message

  ## Returns
  - `{:ok, Auth.t()}` if authentication is successful
  - `{:error, String.t()}` error with the description
  - `:error` if there was an unexpected error
  """
  @spec get_auth_with_web3(String.t(), String.t()) :: :error | {:error, String.t()} | {:ok, Auth.t()}
  def get_auth_with_web3(message, signature) do
    with {:signature, {:ok, %{nonce: nonce, address: address}}} <-
           {:signature, message |> String.trim() |> Siwe.parse_if_valid(signature)},
         {:nonce, {:ok, ^nonce}} <- {:nonce, Internal.get_nonce_for_address(address)},
         {:user, {:ok, user}} <- {:user, Internal.process_web3_user(address, signature)} do
      {:ok, Internal.create_auth(user)}
    else
      {:nonce, {:ok, nil}} ->
        {:error, @request_siwe_message}

      {:nonce, {:ok, _}} ->
        {:error, @wrong_nonce}

      {_step, error} ->
        error
    end
  end
end
