defmodule Explorer.ThirdPartyIntegrations.Auth0.Migrated do
  @moduledoc """
  Module for internal usage, not supposed to be used directly, if
  you want to interact with Auth0, use `Explorer.ThirdPartyIntegrations.Auth0`.

  Provides Auth0 authentication for migrated Auth0 configuration.

  This module implements Auth0 authentication functionality for the migrated Auth0
  configuration where the application identifier is set. It handles user management
  within application-scoped metadata, providing namespaced storage of user
  attributes.

  The module supports both email and web3 authentication flows, focusing on
  managing user identity within an application-specific context. It uses nested
  metadata structures to prevent conflicts between different applications using
  the same Auth0 tenant.
  """

  use Utils.RuntimeEnvHelper,
    auth0_application_identifier: [:ueberauth, Ueberauth.Strategy.Auth0.OAuth, :auth0_application_id]

  alias Explorer.ThirdPartyIntegrations.Auth0.Internal
  alias Ueberauth.Auth
  alias Ueberauth.Strategy.Auth0, as: UeberauthAuth0

  @spec redis_key() :: String.t()
  def redis_key do
    client_id = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)[:client_id]

    client_id <> "auth0:migrated"
  end

  @spec find_users_by_email_query(String.t()) :: String.t()
  def find_users_by_email_query(encoded_email) do
    ~s(email:"#{encoded_email}")
  end

  @spec link_email(String.t(), String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def link_email(session_user_id_without_email, user_id_with_email, _email) do
    auth0_application_id = auth0_application_identifier()

    with {:ok,
          %{
            "user_id" => user_id_without_email,
            "user_metadata" => %{^auth0_application_id => user_without_email_metadata}
          }} <-
           get_user_by_id_from_session(session_user_id_without_email),
         {:ok, user_with_email} <-
           Internal.update_user(
             user_id_with_email,
             user_without_email_metadata,
             "Failed to link email on updating user with email metadata step"
           ),
         {:ok, _} <-
           Internal.update_user(
             user_id_without_email,
             %{"user_metadata" => %{auth0_application_id => %{}}},
             "Failed to link email on updating user without email metadata"
           ) do
      {:ok, user_with_email}
    end
  end

  @spec create_auth(map()) :: Auth.t()
  def create_auth(user) do
    uid = user["user_metadata"][auth0_application_identifier()]["user_id"]
    user = Map.update(user, "user_metadata", nil, fn user_metadata -> user_metadata[auth0_application_identifier()] end)
    conn_stub = %{private: %{auth0_user: user, auth0_token: nil}}

    %Auth{
      uid: uid,
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
      grant_type: :"http://auth0.com/oauth/grant-type/passwordless/otp",
      chain_slug: auth0_application_identifier()
    }
  end

  @spec process_email_user(map()) :: {:ok, map()} | :error | {:error, String.t()}
  def process_email_user(user) do
    if user["user_metadata"][auth0_application_identifier()] do
      {:ok, user}
    else
      Internal.update_user(
        user["user_id"],
        %{
          "user_metadata" => %{
            auth0_application_identifier() => Map.take(user, ["user_id", "name", "nickname", "picture"])
          }
        },
        "Failed to update email user metadata"
      )
    end
  end

  @spec handle_not_found_just_created_email_user(map()) :: {:ok, Auth.t()} | :error | {:error, String.t()}
  def handle_not_found_just_created_email_user(%{"sub" => user_id} = user_from_token) do
    with {:ok, user} <-
           Internal.update_user(
             user_id,
             %{
               "user_metadata" => %{
                 auth0_application_identifier() => Map.take(user_from_token, ["sub", "name", "nickname", "picture"])
               }
             },
             "Failed to update just created email user metadata"
           ) do
      {:ok, create_auth(user)}
    end
  end

  @spec get_user_by_id_from_session(String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def get_user_by_id_from_session(user_id) do
    case Internal.find_users(
           ~s(user_metadata.#{auth0_application_identifier()}.user_id:"#{user_id}"),
           "Failed to find user by id from session"
         ) do
      {:ok, [user]} -> {:ok, user}
      {:ok, []} -> {:error, "User with id from session not found"}
      {:ok, _} -> {:error, "Multiple users with the same id in metadata found"}
      error -> error
    end
  end

  @spec find_users_by_web3_address_query(String.t()) :: String.t()
  def find_users_by_web3_address_query(address) do
    ~s(user_metadata.#{auth0_application_identifier()}.web3_address_hash:"#{address}")
  end

  @spec update_user_with_web3_address(String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def update_user_with_web3_address(session_user_id, address) do
    auth0_application_id = auth0_application_identifier()

    with {:ok, %{"user_id" => user_id, "user_metadata" => %{^auth0_application_id => user_metadata}}} <-
           get_user_by_id_from_session(session_user_id) do
      Internal.update_user(
        user_id,
        %{"user_metadata" => %{auth0_application_id => Map.put(user_metadata, "web3_address_hash", address)}},
        "Failed to update user with web3 address"
      )
    end
  end

  @spec find_or_create_web3_user(String.t(), String.t()) :: {:ok, map()} | :error | {:error, String.t()}
  def find_or_create_web3_user(address, signature) do
    case Internal.find_users_by_web3_address(address) do
      {:ok, [user]} ->
        {:ok, user}

      {:ok, []} ->
        create_web3_user(address, signature)

      {:ok, _} ->
        {:error, "Multiple users with the same web3 address found"}

      error ->
        error
    end
  end

  defp create_web3_user(address, signature) do
    with {:ok, %{"user_id" => user_id} = user} <- Internal.create_web3_user(address, signature, %{}) do
      Internal.update_user(
        user_id,
        %{
          "user_metadata" => %{
            auth0_application_identifier() =>
              Map.merge(
                %{"web3_address_hash" => address},
                Map.take(user, ["user_id", "name", "nickname", "picture"])
              )
          }
        },
        "Failed to update user with web3 address"
      )
    end
  end
end
