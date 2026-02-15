defmodule Explorer.Utility.Microservice do
  @moduledoc """
  Module is responsible for common utils related to microservices.
  """

  alias Utils.ConfigHelper, as: UtilsConfigHelper

  @doc """
    Returns base url of the microservice or nil if it is invalid or not set
  """
  @spec base_url(atom(), atom()) :: nil | binary()
  def base_url(application \\ :explorer, module) do
    url = Application.get_env(application, module)[:service_url]

    if UtilsConfigHelper.valid_url?(url), do: url, else: nil
  end

  @doc """
    Returns :ok if Application.get_env(:explorer, module)[:enabled] is true (module is enabled)
  """
  @spec check_enabled(atom(), atom()) :: :ok | {:error, :disabled}
  def check_enabled(application \\ :explorer, module) do
    if Application.get_env(application, module)[:enabled] && base_url(application, module) do
      :ok
    else
      {:error, :disabled}
    end
  end

  @doc """
  Retrieves the API key for the microservice.

  ## Examples

      iex> Explorer.Utility.Microservice.api_key()
      "your_api_key_here"

  """
  @spec api_key(atom(), atom()) :: String.t() | nil
  def api_key(application \\ :explorer, module) do
    Application.get_env(application, module)[:api_key]
  end
end
