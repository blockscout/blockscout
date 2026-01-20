defmodule Explorer.ThirdPartyIntegrations.Dynamic do
  @moduledoc """
  Provides integration with Dynamic for JWT-based user authentication.

  This module handles authentication by verifying JWT tokens issued by Dynamic
  and transforming their claims into `Ueberauth.Auth` structs. It extracts user
  identity information from token claims, including data from OAuth and
  blockchain verified credentials.

  Dynamic is an authentication provider that supports multiple credential
  formats, including OAuth accounts and blockchain wallet addresses.
  """

  alias Explorer.ThirdPartyIntegrations.Dynamic.Token
  alias Ueberauth.Auth
  alias Ueberauth.Auth.{Extra, Info}

  @doc """
  Authenticates a user by verifying a JWT token and extracting identity information from its claims.

  The function validates the provided JWT token and, upon successful
  verification, constructs an authentication struct containing user identity
  data. It extracts information from the token's claims including user ID,
  email, name, and verified credentials (OAuth and blockchain).

  If the token's scopes include `"requiresAdditionalAuth"`, authentication
  is rejected, requiring further verification steps.

  ## Parameters
  - `token`: A JWT bearer token string to verify and extract claims from.

  ## Returns
  - `{:ok, Auth.t()}` if the token is valid and no additional authentication
    is required.
  - `{:error, String.t()}` if token verification fails or additional
    authentication is required.
  """
  @spec get_auth_from_token(String.t()) :: {:ok, Auth.t()} | {:error, String.t()}
  def get_auth_from_token(token) do
    with {:enabled, true} <- {:enabled, Application.get_env(:explorer, __MODULE__)[:enabled]},
         {:ok, claims} <- Token.verify_and_validate(token) do
      create_auth(claims)
    else
      {:enabled, false} -> {:error, "Dynamic integration is disabled"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp create_auth(claims) do
    if claims["scopes"] && "requiresAdditionalAuth" in claims["scopes"] do
      {:error, "Additional verification required"}
    else
      {:ok, do_create_auth(claims)}
    end
  end

  defp do_create_auth(claims) do
    oauth =
      Enum.find(claims["verified_credentials"] || [], fn
        %{"format" => "oauth"} -> true
        _ -> false
      end)

    blockchain =
      Enum.find(claims["verified_credentials"] || [], fn
        %{"format" => "blockchain"} -> true
        _ -> false
      end)

    %Auth{
      uid: claims["metadata"]["auth0UserId"] || claims["sub"],
      provider: :dynamic,
      info: %Info{
        email: claims["email"],
        name: (oauth && oauth["oauth_display_name"]) || claims["name"],
        nickname: claims["username"],
        image: oauth && List.first(oauth["oauth_account_photos"] || [])
      },
      extra: %Extra{raw_info: %{address_hash: blockchain && blockchain["address"]}}
    }
  end
end
