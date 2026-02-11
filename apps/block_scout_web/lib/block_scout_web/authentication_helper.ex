defmodule BlockScoutWeb.AuthenticationHelper do
  @moduledoc """
  Helper module for authentication.
  """

  @spec validate_sensitive_endpoints_api_key(binary() | nil) ::
          :ok | {:sensitive_endpoints_api_key, any()} | {:api_key, any()}
  def validate_sensitive_endpoints_api_key(api_key_from_request) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, api_key_from_request} do
      :ok
    end
  end
end
