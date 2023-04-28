defmodule Explorer.ThirdPartyIntegrations.Auth0 do
  @moduledoc """
    Module for fetching jwt auth0 Management API (https://auth0.com/docs/api/management/v2) jwt
  """
  @redis_key "auth0"

  def get_m2m_jwt, do: get_m2m_jwt_inner(Redix.command(:redix, ["GET", @redis_key]))

  def get_m2m_jwt_inner({:ok, token}) when not is_nil(token), do: token

  def get_m2m_jwt_inner(_) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Auth0.OAuth)

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

  defp cache_token(token, ttl) do
    chain_id = Application.get_env(:block_scout_web, :chain_id)
    Redix.command(:redix, ["SET", "#{chain_id}_#{@redis_key}", token, "EX", ttl])
    token
  end
end
