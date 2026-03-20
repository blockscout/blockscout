defmodule Explorer.ThirdPartyIntegrations.Keycloak do
  @moduledoc """
  Keycloak Admin REST API client for user management.
  Mirrors Auth0 Management API calls.
  """

  use Utils.RuntimeEnvHelper,
    domain: [:explorer, [__MODULE__, :domain]],
    realm: [:explorer, [__MODULE__, :realm]],
    client_id: [:explorer, [__MODULE__, :client_id]],
    client_secret: [:explorer, [__MODULE__, :client_secret]],
    otp_template: [:explorer, [Explorer.Account, :sendgrid, :otp_template]],
    otp_sender: [:explorer, [Explorer.Account, :sendgrid, :sender]],
    email_webhook_url: [:explorer, [__MODULE__, :email_webhook_url]]

  import Bamboo.{Email, SendGridHelper}

  alias Explorer.Account.Authentication
  alias Explorer.{Helper, HttpClient, Mailer, Vault}
  alias Ueberauth.Auth

  require Logger

  @behaviour Authentication

  @json_headers [{"content-type", "application/json"}]

  @otp_length 6
  @otp_ttl_seconds 300
  @max_otp_attempts 3

  @spec enabled?() :: boolean()
  def enabled? do
    Enum.all?([domain(), realm(), client_id(), client_secret()], &(&1 not in [nil, ""]))
  end

  @impl Authentication
  def send_otp(email, _ip) do
    otp = generate_otp()

    with :ok <- store_otp(email, otp),
         :ok <- deliver_otp_email(email, otp) do
      :ok
    else
      error ->
        Logger.error("Error while sending otp: #{inspect(error)}")
        :error
    end
  end

  @impl Authentication
  def confirm_otp_and_get_auth(email, otp, _ip) do
    case verify_otp(email, otp) do
      :ok -> find_or_create_email_user(email)
      :not_found -> {:error, "Verification code has expired."}
      error -> error
    end
  end

  @impl Authentication
  def send_otp_for_linking(email, ip) do
    case find_users_by_email(email) do
      {:ok, []} -> send_otp(email, ip)
      {:ok, [_ | _]} -> {:error, "Account with this email already exists"}
      error -> error
    end
  end

  @impl Authentication
  def link_email(%{uid: user_id, email: nil}, email, otp, _ip) do
    case verify_otp(email, otp) do
      :ok ->
        with :ok <-
               "#{users_path()}/#{user_id}"
               |> admin_put(%{email: email, emailVerified: true})
               |> handle_update("Failed to link email to user"),
             {:ok, user} <- get_user(user_id) do
          send_registration_webhook(email)
          {:ok, create_auth(user)}
        end

      :not_found ->
        {:error, "Verification code has expired."}

      :error ->
        :error

      {:error, _} = error ->
        error
    end
  end

  def link_email(%{uid: _user_id, email: _}, _email, _otp, _ip) do
    {:error, "User already has an email linked"}
  end

  @impl Authentication
  def find_or_create_web3_user(address_hash, _signature) do
    case find_users_by_address(address_hash) do
      {:ok, []} ->
        with {:ok, user_id} <- create_web3_user(address_hash),
             {:ok, user} <- get_user(user_id) do
          {:ok, create_auth(user, address_hash)}
        end

      {:ok, [user]} ->
        {:ok, create_auth(user, address_hash)}

      {:ok, _} ->
        {:error, "Multiple users with the same address found"}

      error ->
        error
    end
  end

  @impl Authentication
  def link_address(user_id, address_hash) do
    case find_users_by_address(address_hash) do
      {:ok, []} ->
        link_address_to_user(user_id, address_hash)

      {:ok, _} ->
        {:error, "Account with this address already exists"}

      error ->
        error
    end
  end

  defp find_or_create_email_user(email) do
    case find_users_by_email(email) do
      {:ok, []} ->
        with {:ok, user_id} <- create_email_user(email),
             send_registration_webhook(email),
             {:ok, user} <- get_user(user_id) do
          {:ok, create_auth(user)}
        end

      {:ok, [user]} ->
        {:ok, create_auth(user)}

      {:ok, _} ->
        {:error, "Multiple users with the same email found"}

      error ->
        error
    end
  end

  @doc false
  def find_users_by_email(email) do
    case admin_get(users_path(), %{email: email, exact: true}) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status_code: 404}} -> {:ok, []}
      error -> handle_error(error, "Failed to search user by email")
    end
  end

  @doc false
  def find_users_by_address(address) do
    case admin_get(users_path(), %{q: "address:#{String.downcase(address)}"}) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status_code: 404}} -> {:ok, []}
      error -> handle_error(error, "Failed to search user by address")
    end
  end

  defp create_email_user(email) do
    create_user(%{
      username: email,
      email: email,
      emailVerified: true,
      enabled: true
    })
  end

  defp create_web3_user(address_hash) do
    create_user(%{
      username: String.downcase(address_hash),
      enabled: true,
      attributes: %{address: [String.downcase(address_hash)]}
    })
  end

  @doc false
  def create_user(body) do
    with {:ok, %{status_code: 201, headers: headers}} <- admin_post(users_path(), body),
         {:location_id, location_id, _headers} when not is_nil(location_id) <-
           {:location_id, extract_location_id(headers), headers} do
      {:ok, location_id}
    else
      {:location_id, nil, headers} ->
        Logger.error("Failed to extract user ID from Keycloak response headers: #{inspect(headers)}")
        :error

      {:ok, %{status_code: 409}} ->
        {:error, "User already exists"}

      error ->
        handle_error(error, "Failed to create user")
    end
  end

  defp link_address_to_user(user_id, address_hash) do
    with {:ok, user} <- get_user(user_id),
         new_attributes = %{"address" => [String.downcase(address_hash)]},
         merged =
           Map.update(user, "attributes", new_attributes, fn attributes ->
             Map.merge(attributes, new_attributes)
           end),
         :ok <-
           "#{users_path()}/#{user_id}" |> admin_put(merged) |> handle_update("Failed to link address to user"),
         {:ok, user} <- get_user(user_id) do
      {:ok, create_auth(user, address_hash)}
    end
  end

  @doc false
  def get_user(user_id) do
    case admin_get("#{users_path()}/#{user_id}") do
      {:ok, %{status_code: 200, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status_code: 404}} -> {:error, "User not found"}
      error -> handle_error(error, "Failed to get user")
    end
  end

  @doc false
  def update_user(user_id, body) do
    "#{users_path()}/#{user_id}" |> admin_put(body) |> handle_update("Failed to update user")
  end

  defp admin_get(path, params \\ %{}) do
    with {:ok, token} <- get_admin_token() do
      HttpClient.get(
        build_url(path),
        auth_headers(token) ++ @json_headers,
        params: params
      )
    end
  end

  defp admin_post(path, body) do
    with {:ok, token} <- get_admin_token() do
      HttpClient.post(
        build_url(path),
        Jason.encode!(body),
        auth_headers(token) ++ @json_headers
      )
    end
  end

  defp admin_put(path, body) do
    with {:ok, token} <- get_admin_token() do
      HttpClient.request(
        :put,
        build_url(path),
        auth_headers(token) ++ @json_headers,
        Jason.encode!(body)
      )
    end
  end

  defp auth_headers(token), do: [{"authorization", "Bearer #{token}"}]

  defp get_admin_token do
    with {:redix, {:ok, token}} when not is_nil(token) <-
           {:redix, Redix.command(:redix, ["GET", admin_token_key()])},
         {:vault, {:ok, decrypted_token}} <- {:vault, Vault.decrypt(token)} do
      {:ok, decrypted_token}
    else
      {:redix, _} ->
        fetch_and_cache_admin_token()

      {:vault, error} ->
        Logger.error("Failed to decrypt admin token from Redis: #{inspect(error)}")
        {:error, :decryption_failed}
    end
  end

  defp fetch_and_cache_admin_token do
    url = build_url("/realms/#{URI.encode(realm())}/protocol/openid-connect/token")

    body =
      URI.encode_query(%{
        grant_type: "client_credentials",
        client_id: client_id(),
        client_secret: client_secret()
      })

    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    case HttpClient.post(url, body, headers) do
      {:ok, %{status_code: 200, body: resp_body}} ->
        case Jason.decode(resp_body) do
          {:ok, %{"access_token" => token, "expires_in" => ttl}} ->
            Redix.command(:redix, ["SET", admin_token_key(), Vault.encrypt!(token), "EX", ttl - 1])
            {:ok, token}

          _ ->
            :error
        end

      other ->
        Logger.error("Failed to obtain Keycloak admin token: #{inspect(other)}")
        :error
    end
  end

  defp admin_token_key, do: Helper.redis_key("keycloak:#{client_id()}:admin_token")

  defp handle_error({:ok, response}, error_message) do
    Logger.error("#{error_message}: status=#{response.status_code} body=#{response.body}")
    :error
  end

  defp handle_error({:error, reason}, error_message) do
    Logger.error("#{error_message}: #{inspect(reason)}")
    :error
  end

  defp handle_error(:error, error_message) do
    Logger.error("#{error_message}: unknown error")
    :error
  end

  defp handle_update(result, error_message) do
    case result do
      {:ok, %{status_code: 204}} -> :ok
      {:ok, %{status_code: 404}} -> {:error, "User not found"}
      {:ok, %{status_code: 409}} -> {:error, "Email already in use by another account"}
      error -> handle_error(error, error_message)
    end
  end

  defp build_url(path) do
    domain()
    |> URI.parse()
    |> URI.append_path(path)
    |> URI.to_string()
  end

  defp users_path, do: "/admin/realms/#{URI.encode(realm())}/users"

  defp extract_location_id(headers) do
    Enum.find_value(headers, fn {key, value} ->
      String.downcase(key) == "location" && value |> String.split("/") |> List.last()
    end)
  end

  defp otp_key(email), do: Helper.redis_key("#{client_id()}:otp:#{String.downcase(email)}")
  defp otp_attempts_key(email), do: Helper.redis_key("#{client_id()}:otp_attempts:#{String.downcase(email)}")

  defp store_otp(email, otp) do
    case Redix.command(:redix, ["SET", otp_key(email), Vault.encrypt!(otp), "EX", @otp_ttl_seconds]) do
      {:ok, "OK"} ->
        Redix.command(:redix, ["DEL", otp_attempts_key(email)])
        :ok

      error ->
        Logger.error("Failed to store OTP in Redis: #{inspect(error)}")
        :error
    end
  end

  defp verify_otp(email, otp) do
    case fetch_otp(email) do
      {:ok, ^otp} ->
        delete_otp(email)
        :ok

      {:ok, _} ->
        increment_and_check_attempts(email)

      other ->
        other
    end
  end

  defp fetch_otp(email) do
    case Redix.command(:redix, ["GET", otp_key(email)]) do
      {:ok, nil} ->
        :not_found

      {:ok, value} ->
        case Vault.decrypt(value) do
          {:ok, otp} ->
            {:ok, otp}

          {:error, reason} ->
            Logger.error("Failed to decrypt OTP from Redis: #{inspect(reason)}")
            :error
        end

      {:error, reason} ->
        Logger.error("Failed to fetch OTP from Redis: #{inspect(reason)}")
        :error
    end
  end

  defp delete_otp(email) do
    Redix.command(:redix, ["DEL", otp_key(email), otp_attempts_key(email)])
  end

  defp increment_and_check_attempts(email) do
    key = otp_attempts_key(email)

    case Redix.pipeline(:redix, [["INCR", key], ["EXPIRE", key, @otp_ttl_seconds]]) do
      {:ok, [attempts, _]} when attempts >= @max_otp_attempts ->
        delete_otp(email)
        {:error, "Too many wrong verification code attempts. Please request a new code."}

      {:ok, _} ->
        {:error, "Wrong verification code."}

      {:error, reason} ->
        Logger.error("Failed to increment OTP attempts in Redis: #{inspect(reason)}")
        {:error, "Wrong verification code."}
    end
  end

  defp generate_otp do
    4
    |> :crypto.strong_rand_bytes()
    |> :binary.decode_unsigned()
    |> rem(round(:math.pow(10, @otp_length)))
    |> Integer.to_string()
    |> String.pad_leading(@otp_length, "0")
  end

  defp deliver_otp_email(email, otp) do
    email
    |> compose_otp_email(otp)
    |> deliver()
  end

  defp compose_otp_email(to, otp) do
    email = new_email(from: otp_sender(), to: to)

    email
    |> with_template(otp_template())
    |> add_dynamic_field("otp", otp)
    |> add_dynamic_field("ttl_minutes", div(@otp_ttl_seconds, 60))
  end

  defp deliver(email) do
    case Mailer.deliver_now(email, response: false) do
      {:ok, _email} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to deliver OTP email: #{inspect(error)}")
        :error
    end
  end

  defp send_registration_webhook(email), do: do_send_registration_webhook(email, email_webhook_url())

  defp do_send_registration_webhook(email, webhook_url) when not is_nil(webhook_url) do
    payload =
      Jason.encode!(%{
        email: email,
        name: email,
        labels: [Helper.get_app_host()]
      })

    Task.start(fn ->
      case HttpClient.post(webhook_url, payload, @json_headers) do
        {:ok, _} -> :ok
        {:error, reason} -> Logger.error("Registration webhook failed: #{inspect(reason)}")
      end
    end)
  end

  defp do_send_registration_webhook(_email, nil), do: :ok

  defp create_auth(user, address_hash \\ nil) do
    address_hash = address_hash || List.first(user["attributes"]["address"] || [])

    %Auth{
      uid: user["id"],
      provider: :keycloak,
      info: %Auth.Info{
        email: user["email"],
        name: user["firstName"] && user["lastName"] && "#{user["firstName"]} #{user["lastName"]}",
        nickname: user["username"]
      },
      extra: %Auth.Extra{raw_info: %{address_hash: address_hash}}
    }
  end
end
