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

  @doc """
    Function responsible for retrieving machine to machine JWT for interacting with Auth0 Management API.
    Firstly it tries to access cached token and if there is no cached one, token will be requested from Auth0
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

    headers = [{"Content-type", "application/json"}]

    case HTTPoison.post("https://#{config[:domain]}/oauth/token", Jason.encode!(body), headers, []) do
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
    Generates key from chain_id and cookie hash for storing in Redis
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

  @spec link_email(String.t(), String.t(), String.t()) :: :error | {:ok, Auth.t()} | {:error, String.t()}
  def link_email(primary_user_id, email, otp) do
    case find_users_by_email(email) do
      {:ok, []} ->
        with {:ok, token} <- confirm_otp(email, otp),
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

  @spec confirm_otp_and_get_auth(String.t(), String.t()) :: :error | {:error, String.t()} | {:ok, Auth.t()}
  def confirm_otp_and_get_auth(email, otp) do
    with {:ok, token} <- confirm_otp(email, otp),
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

  @spec generate_siwe_message(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_siwe_message(address) do
    nonce = Siwe.generate_nonce()
    {int_chain_id, _} = Integer.parse(Application.get_env(:block_scout_web, :chain_id))

    message = %Siwe.Message{
      domain: Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host],
      address: address,
      statement: "Sign in to Blockscout Account V2 via Ethereum account",
      uri:
        Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:scheme] <>
          "://" <> Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host],
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
        Logger.error(fn -> "Error while caching nonce: #{inspect(error)}" end)
        {:error, "Misconfiguration detected, please contact support."}

      {:message, {:error, error}} ->
        Logger.error(fn -> "Error while generating Siwe Message: #{inspect(error)}" end)
        {:error, error}
    end
  end

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
        {:error, "Wrong nonce in message"}

      {:nonce, _} ->
        {:error, "Request siwe message via /api/account/v2/siwe_message"}

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
        {:error, "Wrong nonce in message"}

      {:nonce, _} ->
        {:error, "Request siwe message via /api/account/v2/siwe_message"}

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

    headers = [{"Content-type", "application/json"}, {"auth0-forwarded-for", ip}]

    case Client.post(client, "/passwordless/start", body, headers) do
      {:ok, %OAuth2.Response{status_code: 200}} ->
        :ok

      other ->
        Logger.error(fn -> ["Error while sending otp: ", inspect(other)] end)

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

    {:error, "Misconfiguration detected, please contact support."}
  end

  defp confirm_otp(email, otp) do
    client = OAuth.client()

    body =
      %{
        username: email,
        otp: otp,
        realm: :email,
        grant_type: :"http://auth0.com/oauth/grant-type/passwordless/otp"
      }
      |> put_client_id_and_secret()

    headers = [{"Content-type", "application/json"}]

    case Client.post(client, "/oauth/token", body, headers) do
      {:ok, %OAuth2.Response{status_code: 200, body: body}} ->
        {:ok, AccessToken.new(body)}

      {:error,
       %OAuth2.Response{
         status_code: 403,
         body:
           %{
             "error" => "unauthorized_client",
             "error_description" =>
               "Grant type 'http://auth0.com/oauth/grant-type/passwordless/otp' not allowed for the client.",
             "error_uri" => "https://auth0.com/docs/clients/client-grant-types"
           } = body
       }} ->
        Logger.error(fn -> ["Need to enable OTP: ", inspect(body)] end)
        {:error, "Misconfiguration detected, please contact support."}

      other ->
        Logger.error(fn -> ["Error while confirming otp: ", inspect(other)] end)

        :error
    end
  end

  defp get_user_by_id(id) do
    case get_m2m_jwt() do
      token when is_binary(token) ->
        client = OAuth.client(token: token)

        case Client.get(client, "/api/v2/users/#{id}") do
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

        case Client.get(client, "/api/v2/users", [], params: %{"q" => ~s(email:"#{email}")}) do
          {:ok, %OAuth2.Response{status_code: 200, body: users}} when is_list(users) ->
            {:ok, users}

          {:error, %OAuth2.Response{status_code: 403, body: %{"errorCode" => "insufficient_scope"} = body}} ->
            Logger.error(["Failed to get web3 user. Insufficient scope: ", inspect(body)])
            {:error, "Misconfiguration detected, please contact support."}

          other ->
            Logger.error(["Error while getting web3 user: ", inspect(other)])
            :error
        end

      nil ->
        Logger.error("Failed to get M2M JWT")
        {:error, "Misconfiguration detected, please contact support."}
    end
  end

  defp maybe_link_email_and_get_auth(%{"email" => email, "user_id" => "email|" <> identity_id = user_id} = user) do
    case get_m2m_jwt() do
      token when is_binary(token) ->
        client = OAuth.client(token: token)

        case Client.get(client, "/api/v2/users", [],
               params: %{"q" => ~s(email:"#{email}" AND NOT user_id:"#{user_id}")}
             ) do
          {:ok, %OAuth2.Response{status_code: 200, body: []}} ->
            {:ok, create_auth(user)}

          {:ok, %OAuth2.Response{status_code: 200, body: [%{"user_id" => primary_user_id} = user]}} ->
            link_users(primary_user_id, identity_id, "email")
            {:ok, create_auth(user)}

          {:ok, %OAuth2.Response{status_code: 200, body: users}} when is_list(users) and length(users) > 1 ->
            merge_users(users)

          {:error, %OAuth2.Response{status_code: 403, body: %{"errorCode" => "insufficient_scope"} = body}} ->
            Logger.error(["Failed to get web3 user. Insufficient scope: ", inspect(body)])
            {:error, "Misconfiguration detected, please contact support."}

          other ->
            Logger.error(["Error while getting web3 user: ", inspect(other)])
            :error
        end

      nil ->
        Logger.error("Failed to get M2M JWT")
        {:error, "Misconfiguration detected, please contact support."}
    end
  end

  defp maybe_link_email_and_get_auth(user) do
    {:ok, create_auth(user)}
  end

  defp merge_users([primary_user | _] = users) do
    identity_map =
      users
      |> Enum.map(& &1["user_id"])
      |> Identity.find_identities()
      |> Map.new(&{&1.uid, &1})

    case users |> Enum.map(&identity_map[&1["user_id"]]) |> Enum.reject(&is_nil(&1)) do
      [primary | to_merge] ->
        case Account.merge(primary, to_merge) do
          {:ok, _} ->
            {:ok, create_auth(primary_user)}

          error ->
            Logger.error(["Error while merging users: ", inspect(error)])
            :error
        end

      _ ->
        {:ok, create_auth(primary_user)}
    end
  end

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
        Logger.error(["Failed to get web3 user. Multiple accounts with the same address found: ", inspect(users)])
        :error

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
             "/api/v2/users",
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
         body = %{"email" => email, "email_verified" => true},
         headers = [{"Content-type", "application/json"}],
         {:ok, %OAuth2.Response{status_code: 200, body: user}} <-
           Client.patch(client, "/api/v2/users/#{user_id}", body, headers) do
      {:ok, user}
    else
      error -> handle_common_errors(error, "Failed to update user email")
    end
  end

  defp update_user_with_web3_address(user_id, address) do
    with token when is_binary(token) <- get_m2m_jwt(),
         client = OAuth.client(token: token),
         body = %{"user_metadata" => %{"web3_address_hash" => address}},
         headers = [{"Content-type", "application/json"}],
         {:ok, %OAuth2.Response{status_code: 200, body: user}} <-
           Client.patch(client, "/api/v2/users/#{user_id}", body, headers) do
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
         headers = [{"Content-type", "application/json"}],
         {:ok, %OAuth2.Response{status_code: 201, body: user}} <-
           Client.post(client, "/api/v2/users", body, headers) do
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

        {:error, "Misconfiguration detected, please contact support."}

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
         headers = [{"Content-type", "application/json"}],
         {:ok, %OAuth2.Response{status_code: 201}} <-
           Client.post(client, "/api/v2/users/#{primary_user_id}/identities", body, headers) do
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
        {:error, "Misconfiguration detected, please contact support."}

      {:error, %OAuth2.Response{status_code: 403, body: %{"errorCode" => "insufficient_scope"} = body}} ->
        Logger.error(["#{error_msg}. Insufficient scope: ", inspect(body)])
        {:error, "Misconfiguration detected, please contact support."}

      other ->
        Logger.error(["#{error_msg}: ", inspect(other)])
        :error
    end
  end
end
