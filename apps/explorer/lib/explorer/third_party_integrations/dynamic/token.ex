defmodule Explorer.ThirdPartyIntegrations.Dynamic.Token do
  @moduledoc """
  JWT token verification for Dynamic.xyz
  """
  use Joken.Config

  alias Explorer.ThirdPartyIntegrations.Dynamic
  alias Explorer.ThirdPartyIntegrations.Dynamic.Strategy

  add_hook(JokenJwks, strategy: Strategy)

  @impl Joken.Config
  def token_config do
    env_id = Application.get_env(:explorer, Dynamic)[:env_id]

    [skip: [:aud]]
    |> default_claims()
    |> add_claim("iss", nil, fn iss ->
      iss == "app.dynamicauth.com/#{env_id}"
    end)
  end
end
