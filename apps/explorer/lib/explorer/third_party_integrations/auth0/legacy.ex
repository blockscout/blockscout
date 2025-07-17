defmodule Explorer.ThirdPartyIntegrations.Auth0.Legacy do
  @moduledoc """
  Module for internal usage, not supposed to be used directly, if
  you want to interact with Auth0, use `Explorer.ThirdPartyIntegrations.Auth0`.

  Provides Auth0 authentication for legacy Auth0 configuration.

  This module implements Auth0 authentication functionality for the legacy Auth0
  configuration where the application identifier is not set. It handles user
  management operations including email and web3 authentication flows, user
  linking, and identity merging.

  The module specializes in managing Auth0 users with different identity
  providers, linking multiple identities to a single user, and handling user
  metadata for both email and web3-based authentication.
  """

  require Logger

  alias Explorer.Account
  alias Explorer.Account.Identity
  alias Explorer.ThirdPartyIntegrations.Auth0
  alias Explorer.ThirdPartyIntegrations.Auth0.Internal
  alias OAuth2.Client
  alias Ueberauth.Auth
  alias Ueberauth.Strategy.Auth0, as: UeberauthAuth0
  alias Ueberauth.Strategy.Auth0.OAuth

  @spec redis_key() :: String.t()
  def redis_key do
    client_id = Application.get_env(:ueberauth, OAuth)[:client_id]

    client_id <> "auth0:legacy"
  end

  @spec find_users_by_email_query(String.t()) :: String.t()
  def find_users_by_email_query(encoded_email) do
    ~s(email:"#{encoded_email}" OR user_metadata.email:"#{encoded_email}")
  end

  @spec link_email(String.t(), String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def link_email(user_id_without_email, user_id_with_email, email) do
    with :ok <- link_users(user_id_without_email, user_id_with_email, "email") do
      update_user_email(user_id_without_email, email)
    end
  end

  @spec create_auth(map()) :: Auth.t()
  def create_auth(user) do
    conn_stub = %{private: %{auth0_user: user, auth0_token: nil}}

    %Auth{
      uid: user["user_id"],
      provider: :auth0,
      strategy: UeberauthAuth0,
      info: UeberauthAuth0.info(conn_stub),
      credentials: %Auth.Credentials{},
      extra: UeberauthAuth0.extra(conn_stub)
    }
  end

  @spec confirm_otp_body(String.t(), String.t()) :: map()
  def confirm_otp_body(email, otp) do
    %{
      username: email,
      otp: otp,
      realm: :email,
      grant_type: :"http://auth0.com/oauth/grant-type/passwordless/otp"
    }
  end

  @spec process_email_user(map()) :: {:ok, map()} | :error | {:error, String.t()}
  def process_email_user(user) do
    maybe_link_email(user)
  end

  @spec handle_not_found_just_created_email_user(map()) :: {:ok, Auth.t()}
  def handle_not_found_just_created_email_user(%{"sub" => user_id} = user_from_token) do
    {:ok, user_from_token |> Map.put("user_id", user_id) |> Internal.create_auth()}
  end

  @spec get_user_by_id_from_session(String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def get_user_by_id_from_session(user_id) do
    Internal.get_user_by_id(user_id)
  end

  @spec find_users_by_web3_address_query(String.t()) :: String.t()
  def find_users_by_web3_address_query(address) do
    ~s|user_id:*siwe*#{address} OR user_id:*Passkey*#{address} OR user_metadata.web3_address_hash:"#{address}" OR (user_id:*Passkey* AND nickname:"#{address}")|
  end

  @spec update_user_with_web3_address(String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def update_user_with_web3_address(user_id, address) do
    Internal.update_user(
      user_id,
      %{"user_metadata" => %{"web3_address_hash" => address}},
      "Failed to update user address"
    )
  end

  @spec find_or_create_web3_user(String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def find_or_create_web3_user(address, signature) do
    case Internal.find_users_by_web3_address(address) do
      {:ok, [%{"user_metadata" => %{"web3_address_hash" => ^address}} = user]} ->
        {:ok, user}

      {:ok, [%{"user_id" => user_id}]} ->
        update_user_with_web3_address(user_id, address)

      {:ok, []} ->
        Internal.create_web3_user(address, signature, %{web3_address_hash: address})

      {:ok, users} when is_list(users) and length(users) > 1 ->
        merge_web3_users(users)

      other ->
        other
    end
  end

  defp link_users(primary_user_id, secondary_identity_id, provider) do
    with token when is_binary(token) <- Auth0.get_m2m_jwt(),
         client = OAuth.client(token: token),
         body = %{
           provider: provider,
           user_id: secondary_identity_id
         },
         {:ok, %OAuth2.Response{status_code: 201}} <-
           Client.post(
             client,
             "#{Internal.users_path()}/#{URI.encode(primary_user_id)}/identities",
             body,
             Internal.json_content_type()
           ) do
      :ok
    else
      error -> Internal.handle_common_errors(error, "Failed to link accounts")
    end
  end

  defp update_user_email(user_id, email) do
    Internal.update_user(user_id, %{"user_metadata" => %{"email" => email}}, "Failed to update user email")
  end

  defp maybe_link_email(%{"email" => email, "user_id" => "email|" <> identity_id = user_id} = user) do
    case Internal.find_users(
           ~s(email:"#{email}" AND NOT user_id:"#{user_id}"),
           "Failed to find legacy users by email"
         ) do
      {:ok, []} ->
        {:ok, user}

      {:ok, [%{"user_id" => primary_user_id} = user]} ->
        link_users(primary_user_id, identity_id, "email")
        maybe_verify_email(user)
        {:ok, user}

      {:ok, users} ->
        merge_email_users(users, identity_id, "email")

      error ->
        error
    end
  end

  defp maybe_link_email(user) do
    {:ok, user}
  end

  defp maybe_verify_email(%{"email_verified" => false, "user_id" => user_id}) do
    with {:ok, _} <-
           Internal.update_user(user_id, %{"email_verified" => true}, "Failed to patch email_verified to true") do
      :ok
    end
  end

  defp maybe_verify_email(_), do: :ok

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
        {:ok, primary_user}

      {{:ok, _}, primary_identity} ->
        link_users(primary_identity.uid, identity_id_to_link, provider_for_linking)
        maybe_verify_email(users_map[primary_identity.uid])
        {:ok, users_map[primary_identity.uid]}

      error ->
        Logger.error(["Error while merging users with the same email: ", inspect(error)])
        :error
    end
  end

  defp merge_web3_users([primary_user | _] = users) do
    identity_map =
      users
      |> Enum.map(& &1["user_id"])
      |> Identity.find_identities()
      |> Map.new(&{&1.uid, &1})

    users_map = users |> Enum.map(&{&1["user_id"], &1}) |> Map.new()

    users
    |> Enum.map(&identity_map[&1["user_id"]])
    |> Enum.reject(&is_nil(&1))
    |> Account.merge()
    |> case do
      {{:ok, 0}, nil} ->
        unless match?(%{"user_metadata" => %{"web3_address_hash" => _}}, primary_user) do
          update_user_with_web3_address(
            primary_user["user_id"],
            primary_user |> Internal.create_auth() |> Identity.address_hash_from_auth()
          )
        end

        {:ok, primary_user}

      {{:ok, _}, primary_identity} ->
        primary_user_from_db = users_map[primary_identity.uid]

        unless match?(%{"user_metadata" => %{"web3_address_hash" => _}}, primary_user_from_db) do
          update_user_with_web3_address(
            primary_user_from_db["user_id"],
            primary_user_from_db |> Internal.create_auth() |> Identity.address_hash_from_auth()
          )
        end

        {:ok, primary_user_from_db}

      error ->
        Logger.error(["Error while merging users with the same address: ", inspect(error)])
        :error
    end
  end
end
