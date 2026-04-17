defmodule Explorer.Account.Authentication do
  @moduledoc """
  Context module for user authentication and third-party identity management.
  """

  alias Explorer.{Account, Helper}
  alias Explorer.Account.Identity
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.ThirdPartyIntegrations.{Auth0, Dynamic, Keycloak}
  alias Ueberauth.Auth

  require Logger

  @callback send_otp(String.t(), String.t()) :: :ok | {:error, String.t()} | :error | {:format, :email}
  @callback send_otp_for_linking(String.t(), String.t()) :: :ok | {:error, String.t()} | :error | {:format, :email}
  @callback confirm_otp_and_get_auth(String.t(), String.t(), String.t()) ::
              {:ok, Auth.t()} | {:error, String.t()} | :error
  @callback link_email(Identity.session(), String.t(), String.t(), String.t()) ::
              {:ok, Auth.t()} | {:error, String.t()} | :error
  @callback find_or_create_web3_user(String.t(), String.t()) :: {:ok, Auth.t()} | {:error, String.t()} | :error
  @callback link_address(String.t(), String.t()) :: {:ok, Auth.t()} | {:error, String.t()} | :error

  @request_siwe_message "Request Sign in with Ethereum message via /api/account/v2/siwe_message"
  @wrong_nonce "Wrong nonce in message"
  @misconfiguration_detected "Misconfiguration detected, please contact support."

  @doc """
  Sends a one-time password to the specified email address using the enabled authentication provider.

  ## Parameters
  - `email`: The email address to send the OTP to
  - `ip`: The IP address of the requester

  ## Returns
  - `:ok` if the OTP was sent successfully
  - `{:error, String.t()}` if the email already exists or sending failed
  - `:error` if there was an unexpected error
  - `{:enabled, false}` if no authentication provider is enabled
  - `{:format, :email}` if the email format is invalid
  """
  @spec send_otp(String.t(), String.t()) :: :ok | {:error, String.t()} | :error | {:enabled, false} | {:format, :email}
  def send_otp(email, ip) do
    with {:ok, module} <- responsible_module() do
      module.send_otp(email, ip)
    end
  end

  @doc """
  Sends a one-time password to the specified email address for account linking using the enabled authentication provider.

  ## Parameters
  - `email`: The email address to send the OTP to
  - `ip`: The IP address of the requester

  ## Returns
  - `:ok` if the OTP was sent successfully
  - `{:error, String.t()}` if an account with the given email already exists
    or sending failed
  - `:error` if there was an unexpected error
  - `{:enabled, false}` if no authentication provider is enabled
  - `{:format, :email}` if the email format is invalid
  """
  @spec send_otp_for_linking(String.t(), String.t()) ::
          :ok | {:error, String.t()} | :error | {:enabled, false} | {:format, :email}
  def send_otp_for_linking(email, ip) do
    with {:ok, module} <- responsible_module() do
      module.send_otp_for_linking(email, ip)
    end
  end

  @doc """
  Confirms a one-time password and retrieves authentication data for the given email using the enabled authentication provider.

  ## Parameters
  - `email`: The email address associated with the OTP
  - `otp`: The one-time password to confirm
  - `ip`: The IP address of the requester

  ## Returns
  - `{:ok, Auth.t()}` if the OTP is confirmed successfully, where `Auth.t()`
    contains the user's authentication data including UID, provider, strategy,
    info, credentials, and extra information
  - `{:error, String.t()}` if confirmation failed with a description of the
    error
  - `:error` if there was an unexpected error
  - `{:enabled, false}` if no authentication provider is enabled
  """
  @spec confirm_otp(String.t(), String.t(), String.t()) ::
          {:ok, Auth.t()} | {:error, String.t()} | :error | {:enabled, false}
  def confirm_otp(email, otp, ip) do
    with {:ok, module} <- responsible_module() do
      module.confirm_otp_and_get_auth(email, otp, ip)
    end
  end

  @doc """
  Links an email address to an existing user account by verifying a one-time password using the enabled authentication provider.

  ## Parameters
  - `user`: The session map of the existing user account; the account must not
    have an email linked (`email: nil`) for the linking to proceed
  - `email`: The email address to link to the account
  - `otp`: The one-time password for verification
  - `ip`: The IP address of the requester

  ## Returns
  - `{:ok, Auth.t()}` if the email was successfully linked, where `Auth.t()`
    contains the user's authentication data including UID, provider, strategy,
    info, credentials, and extra information
  - `{:error, String.t()}` if the account already has an email linked, an
    account with the given email already exists, the OTP is wrong or expired,
    or linking failed with a description of the error
  - `:error` if there was an unexpected error
  - `{:enabled, false}` if no authentication provider is enabled
  """
  @spec link_email(Identity.session(), String.t(), String.t(), String.t()) ::
          {:ok, Auth.t()} | {:error, String.t()} | :error | {:enabled, false}
  def link_email(user, email, otp, ip) do
    with {:ok, module} <- responsible_module() do
      module.link_email(user, email, otp, ip)
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
    - `{:error, "Misconfiguration detected, please contact support."}` if the
      nonce could not be cached due to a Redis configuration problem
    - `{:error, String.t()}` if the SIWE message could not be formatted
  """
  @spec generate_siwe_message(Hash.Address.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_siwe_message(address_hash) do
    checksum_address = Address.checksum(address_hash)
    nonce = Siwe.generate_nonce()
    {int_chain_id, _} = Integer.parse(Application.get_env(:block_scout_web, :chain_id))

    message = %Siwe.Message{
      domain: Helper.get_app_host(),
      address: checksum_address,
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

    with {:cache, {:ok, _nonce}} <- {:cache, cache_nonce_for_address(nonce, checksum_address)},
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
  Verifies a Sign-In with Ethereum (SIWE) message and signature, then finds or
  creates the corresponding web3 user account.

  The message is parsed and validated against the stored nonce for the signing
  address. A nonce must have been previously generated via `generate_siwe_message/1`
  and is consumed (deleted from cache) upon successful verification.

  ## Parameters
  - `message`: The raw SIWE message string to verify
  - `signature`: The hex-encoded EIP-191 signature produced by signing `message`

  ## Returns
  - `{:ok, Auth.t()}` if the message and signature are valid and the user was
    found or created successfully
  - `{:error, "Request Sign in with Ethereum message via /api/account/v2/siwe_message"}`
    if no nonce exists for the signing address (i.e. a SIWE message was never
    requested)
  - `{:error, "Wrong nonce in message"}` if the nonce in the message does not
    match the cached nonce for the address
  - `{:error, String.t()}` if signature parsing or user lookup/creation failed
  - `:error` if there was an unexpected error
  - `{:enabled, false}` if no authentication provider is enabled
  """
  @spec verify_siwe_message(String.t(), String.t()) ::
          {:ok, Auth.t()} | {:error, String.t()} | :error | {:enabled, false}
  def verify_siwe_message(message, signature) do
    with {:module, {:ok, module}} <- {:module, responsible_module()},
         {:signature, {:ok, %{nonce: nonce, address: address}}} <-
           {:signature, message |> String.trim() |> Siwe.parse_if_valid(signature)},
         {:nonce, {:ok, ^nonce}} <- {:nonce, get_nonce_for_address(address)} do
      module.find_or_create_web3_user(address, signature)
    else
      {:nonce, :not_found} ->
        {:error, @request_siwe_message}

      {:nonce, {:ok, _}} ->
        {:error, @wrong_nonce}

      {_step, error} ->
        error
    end
  end

  @doc """
  Links an Ethereum address to an existing user account by verifying a SIWE
  message and signature.

  The message is parsed and validated against the stored nonce for the signing
  address, in the same way as `verify_siwe_message/2`. On success, the verified
  address is associated with the given user in the active authentication provider.

  ## Parameters
  - `user_id`: The ID of the existing user account to link the address to
  - `message`: The raw SIWE message string to verify
  - `signature`: The hex-encoded EIP-191 signature produced by signing `message`

  ## Returns
  - `{:ok, Auth.t()}` if the message and signature are valid and the address was
    successfully linked to the user
  - `{:error, "Wrong nonce in message"}` if the nonce in the message does not
    match the cached nonce for the signing address
  - `{:error, "Request Sign in with Ethereum message via /api/account/v2/siwe_message"}`
    if no nonce is found for the address (e.g. Redis error or nonce was never
    requested)
  - `{:error, String.t()}` if signature parsing or the linking operation failed
  - `:error` if there was an unexpected error
  - `{:enabled, false}` if no authentication provider is enabled
  """
  @spec link_address(String.t(), String.t(), String.t()) ::
          {:ok, Auth.t()} | {:error, String.t()} | :error | {:enabled, false}
  def link_address(user_id, message, signature) do
    with {:module, {:ok, module}} <- {:module, responsible_module()},
         {:signature, {:ok, %{nonce: nonce, address: address}}} <-
           {:signature, message |> String.trim() |> Siwe.parse_if_valid(signature)},
         {:nonce, {:ok, ^nonce}} <- {:nonce, get_nonce_for_address(address)} do
      module.link_address(user_id, address)
    else
      {:nonce, {:ok, _}} ->
        {:error, @wrong_nonce}

      {:nonce, :not_found} ->
        {:error, @request_siwe_message}

      {:nonce, error} ->
        Logger.error("Error while retrieving nonce for address: #{inspect(error)}")
        :error

      {_step, error} ->
        error
    end
  end

  @doc """
  Authenticates a user using a Dynamic-issued JWT token.

  ## Parameters
  - `token`: A JWT token issued by the Dynamic authentication service

  ## Returns
  - `{:ok, Auth.t()}` if the token is valid and the user was found or created
    successfully
  - `{:error, String.t()}` if token validation or user lookup failed
  - `:error` if there was an unexpected error
  """
  @spec authenticate_via_dynamic(String.t()) :: {:ok, Auth.t()} | {:error, String.t()} | :error | {:enabled, false}
  def authenticate_via_dynamic(token) do
    Dynamic.get_auth_from_token(token)
  end

  defp cache_nonce_for_address(nonce, address_hash) do
    case Redix.command(:redix, [
           "SET",
           Helper.redis_key(String.downcase(address_hash) <> "siwe_nonce"),
           nonce,
           "EX",
           300
         ]) do
      {:ok, _} ->
        {:ok, nonce}

      error ->
        Logger.error("Error while caching nonce: #{inspect(error)}")
        {:error, "Redis configuration problem, please contact support."}
    end
  end

  defp get_nonce_for_address(address_hash) do
    cookie_key = Helper.redis_key(String.downcase(address_hash) <> "siwe_nonce")

    case Redix.command(:redix, ["GETDEL", cookie_key]) do
      {:ok, nil} ->
        :not_found

      {:ok, nonce} ->
        {:ok, nonce}

      error ->
        Logger.error("Error while consuming nonce for address: #{inspect(error)}")
        {:error, "Redis configuration problem, please contact support."}
    end
  end

  defp responsible_module do
    cond do
      Auth0.enabled?() -> {:ok, Auth0}
      Keycloak.enabled?() -> {:ok, Keycloak}
      true -> {:enabled, false}
    end
  end
end
