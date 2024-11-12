defmodule Explorer.ThirdPartyIntegrations.Auth0 do
  @moduledoc """
    Module for fetching jwt Auth0 Management API (https://auth0.com/docs/api/management/v2) jwt
  """
  require Logger

  alias Explorer.Account.Identity
  alias Explorer.{Account, Helper, Repo}
  alias OAuth2.{AccessToken, Client}
  alias Ueberauth.Auth
  alias Ueberauth.Strategy.Auth0
  alias Ueberauth.Strategy.Auth0.OAuth

  @redis_key "auth0"

  @request_siwe_message "Request Sign in with Ethereum message via /api/account/v2/siwe_message"
  @wrong_nonce "Wrong nonce in message"
  @misconfiguration_detected "Misconfiguration detected, please contact support."
  @disabled_otp_error_description "Grant type 'http://auth0.com/oauth/grant-type/passwordless/otp' not allowed for the client."
  @users_path "/api/v2/users"
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
    get_m2m_jwt_inner(Redix.command(:redix, ["GET", cookie_key(@redis_key)]))
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

    case HTTPoison.post("https://#{config[:domain]}/oauth/token", Jason.encode!(body), @json_content_type, []) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
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
    Redix.command(:redix, ["SET", cookie_key(@redis_key), token, "EX", ttl])
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
    case find_users_by_email(email) do
      {:ok, []} ->
        do_send_otp(email, ip)

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
    case find_users_by_email(email) do
      {:ok, []} ->
        do_send_otp(email, ip)

      {:ok, [user | _]} ->
        handle_existing_user(user, email, ip)

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
  def link_email(%{uid: primary_user_id, email: nil}, email, otp, ip) do
    case find_users_by_email(email) do
      {:ok, []} ->
        with {:ok, token} <- confirm_otp(email, otp, ip),
             {:ok, %{"sub" => "email|" <> identity_id}} <- get_user_from_token(token),
             :ok <- link_users(primary_user_id, identity_id, "email"),
             {:ok, user} <- update_user_email(primary_user_id, email) do
          {:ok, create_auth(user)}
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
    with {:ok, token} <- confirm_otp(email, otp, ip),
         {:ok, %{"sub" => user_id} = user} <- get_user_from_token(token),
         {:search, _user_from_token, {:ok, user}} <- {:search, user, get_user_by_id(user_id)} do
      maybe_link_email_and_get_auth(user)
    else
      # newly created user, sometimes just created user with otp does not appear in the search
      {:search, %{"sub" => user_id} = user_from_token, {:error, "User not found"}} ->
        {:ok, user_from_token |> Map.put("user_id", user_id) |> create_auth()}

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
  def update_session_with_address_hash(%{address_hash: _} = session), do: {:old, session}

  def update_session_with_address_hash(%{uid: user_id} = session) do
    case get_user_by_id(user_id) do
      {:ok, user} ->
        {:new, Map.put(session, :address_hash, user |> create_auth() |> Identity.address_hash_from_auth())}

      error ->
        Logger.error("Error when updating session with address hash: #{inspect(error)}")
        {:old, session}
    end
  end

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

    with {:cache, {:ok, _nonce}} <- {:cache, cache_nonce_for_address(nonce, address)},
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
         {:nonce, {:ok, ^nonce}} <-
           {:nonce, Redix.command(:redix, ["GET", cookie_key(address <> "siwe_nonce")])},
         Redix.command(:redix, ["DEL", cookie_key(address <> "siwe_nonce")]),
         {:user, {:ok, []}} <- {:user, find_users_by_web3_address(address)},
         {:ok, user} <- update_user_with_web3_address(user_id, address) do
      {:ok, create_auth(user)}
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
         {:nonce, {:ok, ^nonce}} <-
           {:nonce, Redix.command(:redix, ["GET", cookie_key(address <> "siwe_nonce")])},
         {:user, {:ok, user}} <- {:user, find_or_create_web3_user(address, signature)} do
      Redix.command(:redix, ["DEL", cookie_key(address <> "siwe_nonce")])
      {:ok, create_auth(user)}
    else
      {:nonce, {:ok, _}} ->
        {:error, @wrong_nonce}

      {:nonce, _} ->
        {:error, @request_siwe_message}

      {_step, error} ->
        error
    end
  end

  defp handle_existing_user(user, email, ip) do
    user
    |> create_auth()
    |> Identity.find_identity()
    |> handle_identity(email, ip)
  end

  defp handle_identity(nil, email, ip), do: do_send_otp(email, ip)

  defp handle_identity(%Identity{otp_sent_at: otp_sent_at} = identity, email, ip) do
    otp_resend_interval = Application.get_env(:explorer, Account, :otp_resend_interval)

    case Helper.check_time_interval(otp_sent_at, otp_resend_interval) do
      true ->
        identity
        |> Identity.changeset(%{otp_sent_at: DateTime.utc_now()})
        |> Repo.account_repo().update()

        do_send_otp(email, ip)

      interval ->
        {:interval, interval}
    end
  end

  defp do_send_otp(email, ip) do
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

  defp get_user_from_token(%AccessToken{other_params: %{"id_token" => token}}) do
    case Joken.peek_claims(token) do
      {:ok, %{"sub" => _} = user} ->
        {:ok, user}

      error ->
        Logger.error("Error while peeking claims from token: #{inspect(error)}")
        :error
    end
  end

  defp get_user_from_token(token) do
    Logger.error("No id_token in token: #{inspect(Map.update(token, :access_token, "xxx", fn _ -> "xxx" end))}")

    {:error, @misconfiguration_detected}
  end

  defp confirm_otp(email, otp, ip) do
    client = OAuth.client()

    body =
      %{
        username: email,
        otp: otp,
        realm: :email,
        grant_type: :"http://auth0.com/oauth/grant-type/passwordless/otp"
      }
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

      other ->
        Logger.error("Error while confirming otp: #{inspect(other)}")

        :error
    end
  end

  defp get_user_by_id(id) do
    case get_m2m_jwt() do
      token when is_binary(token) ->
        client = OAuth.client(token: token)

        case Client.get(client, "#{@users_path}/#{URI.encode(id)}") do
          {:ok, %OAuth2.Response{status_code: 200, body: %{"user_id" => ^id} = user}} ->
            {:ok, user}

          {:error, %OAuth2.Response{status_code: 404}} ->
            {:error, "User not found"}

          other ->
            Logger.error(["Error while getting user by id: ", inspect(other)])
            :error
        end
    end
  end

  defp find_users_by_email(email) do
    case get_m2m_jwt() do
      token when is_binary(token) ->
        client = OAuth.client(token: token)
        email = URI.encode(email)

        case Client.get(client, @users_path, [],
               params: %{"q" => ~s(email:"#{email}" OR user_metadata.email:"#{email}")}
             ) do
          {:ok, %OAuth2.Response{status_code: 200, body: users}} when is_list(users) ->
            {:ok, users}

          {:error, %OAuth2.Response{status_code: 403, body: %{"errorCode" => "insufficient_scope"} = body}} ->
            Logger.error(["Failed to get web3 user. Insufficient scope: ", inspect(body)])
            {:error, @misconfiguration_detected}

          other ->
            Logger.error(["Error while getting web3 user: ", inspect(other)])
            :error
        end

      nil ->
        Logger.error("Failed to get M2M JWT")
        {:error, @misconfiguration_detected}
    end
  end

  defp maybe_link_email_and_get_auth(%{"email" => email, "user_id" => "email|" <> identity_id = user_id} = user) do
    case get_m2m_jwt() do
      token when is_binary(token) ->
        client = OAuth.client(token: token)

        case Client.get(client, @users_path, [],
               params: %{"q" => ~s(email:"#{URI.encode(email)}" AND NOT user_id:"#{URI.encode(user_id)}")}
             ) do
          {:ok, %OAuth2.Response{status_code: 200, body: []}} ->
            {:ok, create_auth(user)}

          {:ok, %OAuth2.Response{status_code: 200, body: [%{"user_id" => primary_user_id} = user]}} ->
            link_users(primary_user_id, identity_id, "email")
            maybe_verify_email(user)
            {:ok, create_auth(user)}

          {:ok, %OAuth2.Response{status_code: 200, body: users}} when is_list(users) and length(users) > 1 ->
            merge_email_users(users, identity_id, "email")

          {:error, %OAuth2.Response{status_code: 403, body: %{"errorCode" => "insufficient_scope"} = body}} ->
            Logger.error(["Failed to get web3 user. Insufficient scope: ", inspect(body)])
            {:error, @misconfiguration_detected}

          other ->
            Logger.error(["Error while getting web3 user: ", inspect(other)])
            :error
        end

      nil ->
        Logger.error("Failed to get M2M JWT")
        {:error, @misconfiguration_detected}
    end
  end

  defp maybe_link_email_and_get_auth(user) do
    {:ok, create_auth(user)}
  end

  defp merge_web3_users([primary_user | _] = users) do
    identity_map =
      users
      |> Enum.map(& &1["user_id"])
      |> Identity.find_identities()
      |> Map.new(&{&1.uid, &1})

    users_map = users |> Enum.map(&{&1["user_id"], &1}) |> Map.new()

    case users |> Enum.map(&identity_map[&1["user_id"]]) |> Enum.reject(&is_nil(&1)) |> Account.merge() do
      {{:ok, 0}, nil} ->
        unless match?(%{"user_metadata" => %{"web3_address_hash" => _}}, primary_user) do
          update_user_with_web3_address(
            primary_user["user_id"],
            primary_user |> create_auth() |> Identity.address_hash_from_auth()
          )
        end

        {:ok, primary_user}

      {{:ok, _}, primary_identity} ->
        primary_user_from_db = users_map[primary_identity.uid]

        unless match?(%{"user_metadata" => %{"web3_address_hash" => _}}, primary_user_from_db) do
          update_user_with_web3_address(
            primary_user_from_db["user_id"],
            primary_user_from_db |> create_auth() |> Identity.address_hash_from_auth()
          )
        end

        {:ok, primary_user_from_db}

      error ->
        Logger.error(["Error while merging users with the same address: ", inspect(error)])
        :error
    end
  end

  defp merge_email_users([primary_user | _] = users, identity_id_to_link, provider_for_linking) do
    identity_map =
      users
      |> Enum.map(& &1["user_id"])
      |> Identity.find_identities()
      |> Map.new(&{&1.uid, &1})

    users_map = users |> Enum.map(&{&1["user_id"], &1}) |> Map.new()

    case users |> Enum.map(&identity_map[&1["user_id"]]) |> Enum.reject(&is_nil(&1)) |> Account.merge() do
      {{:ok, 0}, nil} ->
        link_users(primary_user["user_id"], identity_id_to_link, provider_for_linking)
        maybe_verify_email(primary_user)
        {:ok, create_auth(primary_user)}

      {{:ok, _}, primary_identity} ->
        link_users(primary_identity.uid, identity_id_to_link, provider_for_linking)
        maybe_verify_email(users_map[primary_identity.uid])
        {:ok, create_auth(users_map[primary_identity.uid])}

      error ->
        Logger.error(["Error while merging users with the same email: ", inspect(error)])
        :error
    end
  end

  defp maybe_verify_email(%{"email_verified" => false, "user_id" => user_id}) do
    with token when is_binary(token) <- get_m2m_jwt(),
         client = OAuth.client(token: token),
         body = %{"email_verified" => true},
         {:ok, %OAuth2.Response{status_code: 200, body: _user}} <-
           Client.patch(client, "#{@users_path}/#{URI.encode(user_id)}", body, @json_content_type) do
      :ok
    else
      error -> handle_common_errors(error, "Failed to patch email_verified to true")
    end
  end

  defp maybe_verify_email(_), do: :ok

  defp cache_nonce_for_address(nonce, address) do
    case Redix.command(:redix, ["SET", cookie_key(address <> "siwe_nonce"), nonce, "EX", 300]) do
      {:ok, _} -> {:ok, nonce}
      err -> err
    end
  end

  defp find_or_create_web3_user(address, signature) do
    case find_users_by_web3_address(address) do
      {:ok, [%{"user_metadata" => %{"web3_address_hash" => ^address}} = user]} ->
        {:ok, user}

      {:ok, [%{"user_id" => user_id}]} ->
        update_user_with_web3_address(user_id, address)

      {:ok, []} ->
        create_web3_user(address, signature)

      {:ok, users} when is_list(users) and length(users) > 1 ->
        merge_web3_users(users)

      other ->
        other
    end
  end

  defp find_users_by_web3_address(address) do
    with token when is_binary(token) <- get_m2m_jwt(),
         client = OAuth.client(token: token),
         {:ok, %OAuth2.Response{status_code: 200, body: users}} when is_list(users) <-
           Client.get(
             client,
             @users_path,
             [],
             params: %{
               "q" =>
                 ~s|user_id:*siwe*#{address} OR user_id:*Passkey*#{address} OR user_metadata.web3_address_hash:"#{address}" OR (user_id:*Passkey* AND nickname:"#{address}")|
             }
           ) do
      {:ok, users}
    else
      error -> handle_common_errors(error, "Failed to search user by address")
    end
  end

  defp update_user_email(user_id, email) do
    with token when is_binary(token) <- get_m2m_jwt(),
         client = OAuth.client(token: token),
         body = %{"user_metadata" => %{"email" => email}},
         {:ok, %OAuth2.Response{status_code: 200, body: user}} <-
           Client.patch(client, "#{@users_path}/#{URI.encode(user_id)}", body, @json_content_type) do
      {:ok, user}
    else
      error -> handle_common_errors(error, "Failed to update user email")
    end
  end

  defp update_user_with_web3_address(user_id, address) do
    with token when is_binary(token) <- get_m2m_jwt(),
         client = OAuth.client(token: token),
         body = %{"user_metadata" => %{"web3_address_hash" => address}},
         {:ok, %OAuth2.Response{status_code: 200, body: user}} <-
           Client.patch(client, "#{@users_path}/#{URI.encode(user_id)}", body, @json_content_type) do
      {:ok, user}
    else
      error -> handle_common_errors(error, "Failed to update user address")
    end
  end

  defp create_web3_user(address, signature) do
    with token when is_binary(token) <- get_m2m_jwt(),
         client = OAuth.client(token: token),
         body = %{
           username: address,
           password: signature,
           email_verified: true,
           connection: "Username-Password-Authentication",
           user_metadata: %{web3_address_hash: address}
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

  defp link_users(primary_user_id, secondary_identity_id, provider) do
    with token when is_binary(token) <- get_m2m_jwt(),
         client = OAuth.client(token: token),
         body = %{
           provider: provider,
           user_id: secondary_identity_id
         },
         {:ok, %OAuth2.Response{status_code: 201}} <-
           Client.post(client, "#{@users_path}/#{URI.encode(primary_user_id)}/identities", body, @json_content_type) do
      :ok
    else
      error -> handle_common_errors(error, "Failed to link accounts")
    end
  end

  defp create_auth(user) do
    conn_stub = %{private: %{auth0_user: user, auth0_token: nil}}

    %Auth{
      uid: user["user_id"],
      provider: :auth0,
      strategy: Auth0,
      info: Auth0.info(conn_stub),
      credentials: %Auth.Credentials{},
      extra: Auth0.extra(conn_stub)
    }
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

  defp handle_common_errors(error, error_msg) do
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
end
