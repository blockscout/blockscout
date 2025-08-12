defmodule Explorer.ThirdPartyIntegrations.Auth0.Internal do
  @moduledoc """
  Module for internal usage, not supposed to be used directly, if
  you want to interact with Auth0, use `Explorer.ThirdPartyIntegrations.Auth0`.

  Provides internal implementation for Auth0 authentication functionality.

  This module handles core Auth0 operations including user management, OTP verification,
  web3 authentication, and user identity handling. It supports both legacy and migrated
  Auth0 configurations, and implements various authentication flows such as email-based
  OTP authentication and web3 wallet-based authentication.

  The module serves as the internal implementation layer for the Explorer application's
  Auth0 integration, managing API interactions with Auth0 services while providing error
  handling and logging capabilities.
  """

  require Logger

  alias Explorer.Account.Identity
  alias Explorer.{Account, Helper, Repo}
  alias Explorer.Chain.Address
  alias Explorer.ThirdPartyIntegrations.Auth0
  alias Explorer.ThirdPartyIntegrations.Auth0.{Legacy, Migrated}
  alias OAuth2.{AccessToken, Client}
  alias Ueberauth.Strategy.Auth0.OAuth

  @misconfiguration_detected "Misconfiguration detected, please contact support."
  @disabled_otp_error_description "Grant type 'http://auth0.com/oauth/grant-type/passwordless/otp' not allowed for the client."
  @users_path "/api/v2/users"
  @json_content_type [{"Content-type", "application/json"}]

  def users_path, do: @users_path
  def json_content_type, do: @json_content_type

  @doc """
  Returns the Redis key prefix for Auth0-related cached data.

  Delegates to the appropriate Auth0 module (Legacy or Migrated) to provide the
  correct Redis key prefix based on the current Auth0 configuration:
  - Legacy: Returns "auth0"
  - Migrated: Returns "auth0_migrated"

  ## Returns
  - `String.t()`: The Redis key prefix to use for Auth0-related data
  """
  @spec redis_key() :: String.t()
  def redis_key do
    auth0_module().redis_key()
  end

  @doc """
  Searches for Auth0 users by email address.

  Encodes the email, creates a query using the appropriate Auth0 module
  (Legacy or Migrated), and searches for users matching the query.

  ## Parameters
  - `email`: The email address to search for

  ## Returns
  - `{:ok, [map()]}`: List of user objects if successful
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec find_users_by_email(String.t()) :: {:ok, [map()]} | :error | {:error, String.t()}
  def find_users_by_email(email) do
    email
    |> URI.encode()
    |> auth0_module().find_users_by_email_query()
    |> find_users("Failed to search user by email")
  end

  @doc """
  Searches for Auth0 users based on a provided query string.

  Obtains an M2M JWT token, creates an OAuth client, and sends a request to the Auth0
  Users API with the provided query. Handles any errors through the common error
  handling mechanism.

  ## Parameters
  - `q`: The query string for searching users in Auth0
  - `error_message`: Custom error message for logging (defaults to "Failed to find users")

  ## Returns
  - `{:ok, [map()]}`: List of user objects if successful
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec find_users(String.t(), String.t()) :: {:ok, [map()]} | :error | {:error, String.t()}
  def find_users(q, error_message \\ "Failed to find users") do
    with token when is_binary(token) <- Auth0.get_m2m_jwt(),
         client = OAuth.client(token: token),
         {:ok, %OAuth2.Response{status_code: 200, body: users}} when is_list(users) <-
           Client.get(client, @users_path, [], params: [q: q]) do
      {:ok, users}
    else
      error -> handle_common_errors(error, error_message)
    end
  end

  @doc """
  Sends a one-time password (OTP) to the specified email address.

  Initiates the Auth0 passwordless authentication flow by requesting an OTP code be
  sent to the user's email. Includes the client's IP address in the request for audit
  and security purposes.

  ## Parameters
  - `email`: The email address to which the OTP will be sent
  - `ip`: The IP address of the client requesting the OTP

  ## Returns
  - `:ok`: If the OTP was successfully sent
  - `:error`: If there was an error sending the OTP
  """
  @spec send_otp(String.t(), String.t()) :: :ok | :error
  def send_otp(email, ip) do
    client = OAuth.client()

    body =
      %{
        email: email,
        connection: :email,
        send: :code
      }
      |> put_client_id_and_secret()

    headers = [{"auth0-forwarded-for", ip} | @json_content_type]

    case Client.post(client, "/passwordless/start", body, headers) do
      {:ok, %OAuth2.Response{status_code: 200}} ->
        :ok

      other ->
        Logger.error("Error while sending otp: ", inspect(other))

        :error
    end
  end

  @doc """
  Processes an existing Auth0 user and manages OTP authentication flow.

  Creates an auth structure from the user, finds the corresponding identity record,
  and handles the identity by either sending an OTP or checking the resend interval.

  ## Parameters
  - `user`: The Auth0 user map containing user information
  - `email`: The email address of the user
  - `ip`: The IP address of the client making the request

  ## Returns
  - `:ok`: If OTP was successfully sent
  - `:error`: If there was an error in the process
  - `{:interval, integer()}`: If OTP was recently sent and the resend interval hasn't elapsed
  """
  @spec handle_existing_user(map(), String.t(), String.t()) :: :ok | :error | {:interval, integer()}
  def handle_existing_user(user, email, ip) do
    user
    |> create_auth()
    |> Identity.find_identity()
    |> handle_identity(email, ip)
  end

  @doc """
  Validates a one-time password (OTP) for the specified email.

  Attempts to authenticate with Auth0 using the provided email and OTP code. Includes
  the client's IP address for audit and security purposes. Handles various error
  scenarios with specific error messages.

  ## Parameters
  - `email`: The email address associated with the OTP
  - `otp`: The one-time password code to validate
  - `ip`: The IP address of the client submitting the OTP

  ## Returns
  - `{:ok, AccessToken.t()}`: Access token if OTP validation succeeds
  - `{:error, "Wrong verification code."}`: If the OTP is incorrect
  - `{:error, "Max attempts reached. Please resend code."}`: If maximum attempt limit exceeded
  - `{:error, String.t()}`: For other known errors with descriptive messages
  - `:error`: For unspecified errors
  """
  @spec confirm_otp(String.t(), String.t(), String.t()) :: {:ok, AccessToken.t()} | :error | {:error, String.t()}
  def confirm_otp(email, otp, ip) do
    client = OAuth.client()

    body =
      email
      |> auth0_module().confirm_otp_body(otp)
      |> put_client_id_and_secret()

    headers = [{"auth0-forwarded-for", ip} | @json_content_type]

    case Client.post(client, "/oauth/token", body, headers) do
      {:ok, %OAuth2.Response{status_code: 200, body: body}} ->
        {:ok, AccessToken.new(body)}

      {:error,
       %OAuth2.Response{
         status_code: 403,
         body:
           %{
             "error" => "unauthorized_client",
             "error_description" => @disabled_otp_error_description,
             "error_uri" => "https://auth0.com/docs/clients/client-grant-types"
           } = body
       }} ->
        Logger.error("Need to enable OTP: #{inspect(body)}")
        {:error, @misconfiguration_detected}

      {:error,
       %OAuth2.Response{
         status_code: 403,
         body: %{"error" => "invalid_grant", "error_description" => "Wrong email or verification code."}
       }} ->
        {:error, "Wrong verification code."}

      {:error,
       %OAuth2.Response{
         status_code: 403,
         body: %{
           "error" => "invalid_grant",
           "error_description" => "You've reached the maximum number of attempts. Please try to login again."
         }
       }} ->
        {:error, "Max attempts reached. Please resend code."}

      other ->
        Logger.error("Error while confirming otp: #{inspect(other)}")

        :error
    end
  end

  @doc """
  Extracts user information from an Auth0 access token.

  Retrieves the user claims from the ID token within the access token. Handles two
  scenarios: tokens with valid ID tokens, and tokens missing ID tokens.

  ## Parameters
  - `token`: The OAuth2 AccessToken struct containing Auth0 authentication information

  ## Returns
  - `{:ok, map()}`: User claims if successfully extracted from the token
  - `:error`: If there was an error decoding the claims
  - `{:error, String.t()}`: If the token doesn't contain an ID token
  """
  @spec get_user_from_token(AccessToken.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def get_user_from_token(%AccessToken{other_params: %{"id_token" => token}}) do
    case Joken.peek_claims(token) do
      {:ok, %{"sub" => _} = user} ->
        {:ok, user}

      error ->
        Logger.error("Error while peeking claims from token: #{inspect(error)}")
        :error
    end
  end

  def get_user_from_token(token) do
    Logger.error("No id_token in token: #{inspect(Map.update(token, :access_token, "xxx", fn _ -> "xxx" end))}")

    {:error, @misconfiguration_detected}
  end

  @doc """
  Links an email-based identity to a user who doesn't have an email.

  Delegates to the appropriate Auth0 module implementation (Legacy or Migrated) to
  associate an email address with a user. The implementation varies depending on
  the Auth0 configuration:
  - Legacy: Links the users and updates the email for the user without email
  - Migrated: Transfers metadata between users and updates both user records

  ## Parameters
  - `user_id_without_email`: The ID of the user who doesn't have an email
  - `user_id_with_email`: The ID of the user who has the email to be linked
  - `email`: The email address to link

  ## Returns
  - `{:ok, map()}`: User information if linking was successful
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec link_email(String.t(), String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def link_email(user_id_without_email, user_id_with_email, email) do
    auth0_module().link_email(user_id_without_email, user_id_with_email, email)
  end

  @doc """
  Creates a Ueberauth authentication structure from an Auth0 user.

  Delegates to the appropriate Auth0 module (Legacy or Migrated) to construct a
  standardized Ueberauth.Auth struct from an Auth0 user object. The implementation
  varies based on the Auth0 configuration:
  - Legacy: Uses the user_id directly from the user object
  - Migrated: Extracts the user_id from nested metadata within the user object

  ## Parameters
  - `user`: Map containing Auth0 user information

  ## Returns
  - `Ueberauth.Auth.t()`: A structured authentication object containing user information
  """
  @spec create_auth(map()) :: Ueberauth.Auth.t()
  def create_auth(user) do
    auth0_module().create_auth(user)
  end

  @doc """
  Retrieves Auth0 user information by user ID.

  Obtains an M2M JWT token, creates an OAuth client, and sends a request to the Auth0
  Users API with the specified user ID. Returns the user information or handles errors
  appropriately.

  ## Parameters
  - `id`: The Auth0 user ID to retrieve

  ## Returns
  - `{:ok, map()}`: User information if found
  - `{:error, "User not found"}`: If the user ID doesn't exist
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec get_user_by_id(String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def get_user_by_id(id) do
    with token when is_binary(token) <- Auth0.get_m2m_jwt(),
         client = OAuth.client(token: token),
         {:ok, %OAuth2.Response{status_code: 200, body: %{"user_id" => ^id} = user}} <-
           Client.get(client, "#{@users_path}/#{URI.encode(id)}") do
      {:ok, user}
    else
      {:error, %OAuth2.Response{status_code: 404}} -> {:error, "User not found"}
      error -> handle_common_errors(error, "Failed to get user by id")
    end
  end

  @doc """
  Processes an email-based Auth0 user account.

  Delegates to the appropriate Auth0 module based on configuration. The behavior
  differs between implementations:
  - Legacy: Attempts to link the email user with existing accounts having the same
    email address, potentially merging multiple accounts
  - Migrated: Updates the user with application-specific metadata if not already
    present

  ## Parameters
  - `user`: Map containing Auth0 user information

  ## Returns
  - `{:ok, map()}`: User information after processing
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec process_email_user(map()) :: {:ok, map()} | :error | {:error, String.t()}
  def process_email_user(user) do
    auth0_module().process_email_user(user)
  end

  @spec handle_not_found_just_created_email_user(map()) :: {:ok, Ueberauth.Auth.t()}
  def handle_not_found_just_created_email_user(user_from_token) do
    auth0_module().handle_not_found_just_created_email_user(user_from_token)
  end

  @doc """
  Ensures a session contains an address hash value.

  For sessions that already have an address hash, returns the unchanged session.
  For sessions without an address hash but with a user ID, retrieves the user from
  Auth0 and adds the address hash to the session. Uses different retrieval methods
  based on Auth0 module configuration:
  - Legacy: Retrieves the user directly by ID
  - Migrated: Finds the user by querying metadata for the application-specific user ID

  ## Parameters
  - `session`: Map containing session information

  ## Returns
  - `{:old, map()}`: The original session if it already contains an address hash or if
    retrieval fails
  - `{:new, map()}`: Updated session with the address hash if retrieval succeeds
  """
  @spec update_session_with_address_hash(map()) ::
          {:new, %{:address_hash => nil | binary(), optional(any()) => any()}}
          | {:old, map()}
  def update_session_with_address_hash(%{address_hash: _} = session), do: {:old, session}

  def update_session_with_address_hash(%{uid: user_id} = session) do
    case auth0_module().get_user_by_id_from_session(user_id) do
      {:ok, user} ->
        {:new, Map.put(session, :address_hash, user |> create_auth() |> Identity.address_hash_from_auth())}

      error ->
        Logger.error("Error when updating session with address hash: #{inspect(error)}")
        {:old, session}
    end
  end

  @doc """
  Caches a nonce value for Sign-In with Ethereum (SIWE) authentication.

  Stores the provided nonce in Redis with an expiration time of 300 seconds (5 minutes),
  using a key derived from the wallet address. This cached nonce is used for the SIWE
  authentication flow to prevent replay attacks.

  ## Parameters
  - `nonce`: The random nonce value to cache
  - `address`: The Ethereum wallet address associated with the nonce

  ## Returns
  - `{:ok, nonce}`: If the nonce was successfully cached
  - `{:error, reason}`: If there was an error caching the nonce
  """
  @spec cache_nonce_for_address(nonce, String.t()) ::
          {:ok, nonce} | {:error, atom() | Redix.Error.t() | Redix.ConnectionError.t()}
        when nonce: String.t()
  def cache_nonce_for_address(nonce, address) do
    case Redix.command(:redix, ["SET", Auth0.cookie_key(address <> "siwe_nonce"), nonce, "EX", 300]) do
      {:ok, _} -> {:ok, nonce}
      error -> error
    end
  end

  def get_nonce_for_address(address_hash) do
    cookie_key = Auth0.cookie_key(Address.checksum(address_hash) <> "siwe_nonce")

    with {:get, {:ok, nonce}} <- {:get, Redix.command(:redix, ["GET", cookie_key])},
         {:del, {:ok, _}} <- {:del, Redix.command(:redix, ["DEL", cookie_key])} do
      {:ok, nonce}
    else
      _ -> {:error, "Redis configuration problem, please contact support."}
    end
  end

  @doc """
  Searches for Auth0 users associated with a specific web3 wallet address.

  Constructs a query using the appropriate Auth0 module implementation (Legacy or
  Migrated) and searches for users matching the query. The search criteria differ
  between implementations:
  - Legacy: Searches across multiple fields including user_id and metadata
  - Migrated: Searches specifically in the application-scoped metadata

  ## Parameters
  - `address`: The web3 wallet address to search for

  ## Returns
  - `{:ok, [map()]}`: List of user objects if successful
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec find_users_by_web3_address(String.t()) :: {:ok, [map()]} | :error | {:error, String.t()}
  def find_users_by_web3_address(address) do
    address
    |> auth0_module().find_users_by_web3_address_query()
    |> find_users("Failed to find users by address")
  end

  @doc """
  Associates a web3 wallet address with an Auth0 user.

  Delegates to the appropriate Auth0 module implementation (Legacy or Migrated) to
  update the user's metadata with their web3 wallet address. The implementation
  differs based on Auth0 configuration:
  - Legacy: Directly updates the user's metadata with the address
  - Migrated: First retrieves the user by session ID, then updates the application-scoped
    metadata with the address

  ## Parameters
  - `user_id`: The Auth0 user ID to update
  - `address`: The web3 wallet address to associate with the user

  ## Returns
  - `{:ok, map()}`: Updated user information if successful
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec update_user_with_web3_address(String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def update_user_with_web3_address(user_id, address) do
    auth0_module().update_user_with_web3_address(user_id, address)
  end

  @doc """
  Updates an Auth0 user's information.

  Obtains an M2M JWT token, creates an OAuth client, and sends a PATCH request to the
  Auth0 Users API to update the specified user with the provided data. Handles any
  errors through the common error handling mechanism.

  ## Parameters
  - `user_id`: The Auth0 user ID to update
  - `body`: The data to update (usually a map that will be JSON-encoded)
  - `error_message`: Custom error message for logging (defaults to "Failed to update user")

  ## Returns
  - `{:ok, map()}`: Updated user information if successful
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec update_user(String.t(), map(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def update_user(user_id, body, error_message \\ "Failed to update user") do
    with token when is_binary(token) <- Auth0.get_m2m_jwt(),
         client = OAuth.client(token: token),
         {:ok, %OAuth2.Response{status_code: 200, body: user}} <-
           Client.patch(client, "#{@users_path}/#{URI.encode(user_id)}", body, @json_content_type) do
      {:ok, user}
    else
      error -> handle_common_errors(error, error_message)
    end
  end

  @doc """
  Processes authentication for a web3 wallet address.

  Delegates to the appropriate Auth0 module (Legacy or Migrated) to find an existing
  user with the provided address or create a new one. The implementation differs based
  on Auth0 configuration:
  - Legacy: Finds existing users by address, updates if found without address metadata,
    creates a new user if none found, or merges multiple matching users
  - Migrated: Finds one user, creates a new user with application-scoped metadata if none
    found, or returns an error if multiple users are found

  ## Parameters
  - `address`: The web3 wallet address for authentication
  - `signature`: The cryptographic signature for authentication

  ## Returns
  - `{:ok, map()}`: User information if processing succeeds
  - `:error`: If an unspecified error occurs
  - `{:error, String.t()}`: If a known error occurs with error message
  """
  @spec process_web3_user(String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def process_web3_user(address, signature) do
    auth0_module().find_or_create_web3_user(address, signature)
  end

  @doc """
  Creates a new Auth0 user with web3 wallet credentials.

  Obtains an M2M JWT token, creates an OAuth client, and sends a request to the Auth0
  Users API to create a new user with the web3 wallet address as username and the
  signature as password. The user is created without an email address, which requires
  specific Auth0 connection configuration.

  ## Parameters
  - `address`: The web3 wallet address to use as username
  - `signature`: The cryptographic signature to use as password
  - `metadata`: Additional metadata to store with the user

  ## Returns
  - `{:ok, map()}`: Created user information if successful
  - `{:error, String.t()}`: If a configuration issue is detected
  - `:error`: If an unspecified error occurs
  """
  @spec create_web3_user(String.t(), String.t(), map()) :: {:ok, map()} | :error | {:error, String.t()}
  def create_web3_user(address, signature, metadata) do
    with token when is_binary(token) <- Auth0.get_m2m_jwt(),
         client = OAuth.client(token: token),
         body = %{
           username: address,
           password: signature,
           email_verified: true,
           connection: "Username-Password-Authentication",
           user_metadata: metadata
         },
         {:ok, %OAuth2.Response{status_code: 201, body: user}} <-
           Client.post(client, @users_path, body, @json_content_type) do
      {:ok, user}
    else
      {:error,
       %OAuth2.Response{
         status_code: 400,
         body:
           %{
             "errorCode" => "invalid_body",
             "message" => "Payload validation error: 'Missing required property: email'."
           } = body
       }} ->
        Logger.error([
          "Failed to create web3 user. Need to allow users without email in Username-Password-Authentication connection: ",
          inspect(body)
        ])

        {:error, @misconfiguration_detected}

      error ->
        handle_common_errors(error, "Failed to create web3 user")
    end
  end

  @doc """
  Standardizes error handling for Auth0 API requests.

  Processes common error patterns from Auth0 API responses, logs appropriate error
  messages, and returns standardized error formats. Specifically handles missing JWT
  tokens and insufficient scope errors with user-friendly messages.

  ## Parameters
  - `error`: The error value or structure to handle
  - `error_msg`: A descriptive message for logging that explains the context of the error

  ## Returns
  - `{:error, String.t()}`: For known error types with a user-friendly message
  - `:error`: For unspecified errors
  """
  @spec handle_common_errors(any(), String.t()) :: :error | {:error, String.t()}
  def handle_common_errors(error, error_msg) do
    case error do
      nil ->
        Logger.error("Failed to get M2M JWT")
        {:error, @misconfiguration_detected}

      {:error, %OAuth2.Response{status_code: 403, body: %{"errorCode" => "insufficient_scope"} = body}} ->
        Logger.error(["#{error_msg}. Insufficient scope: ", inspect(body)])
        {:error, @misconfiguration_detected}

      other ->
        Logger.error(["#{error_msg}: ", inspect(other)])
        :error
    end
  end

  defp auth0_module do
    if Application.get_env(:ueberauth, OAuth)[:auth0_application_id] === "" do
      Legacy
    else
      Migrated
    end
  end

  defp put_client_id_and_secret(map) do
    auth0_config = Application.get_env(:ueberauth, OAuth)

    Map.merge(
      map,
      %{
        client_id: auth0_config[:client_id],
        client_secret: auth0_config[:client_secret]
      }
    )
  end

  defp handle_identity(nil, email, ip), do: send_otp(email, ip)

  defp handle_identity(%Identity{otp_sent_at: otp_sent_at} = identity, email, ip) do
    otp_resend_interval = Application.get_env(:explorer, Account)[:otp_resend_interval]

    case Helper.check_time_interval(otp_sent_at, otp_resend_interval) do
      true ->
        identity |> Identity.changeset(%{otp_sent_at: DateTime.utc_now()}) |> Repo.account_repo().update()

        send_otp(email, ip)

      interval ->
        {:interval, interval}
    end
  end
end
