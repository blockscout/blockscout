defmodule Explorer.Utility.Microservice do
  @moduledoc """
  Module is responsible for common utils related to microservices.
  """
  def base_url(application \\ :explorer, module) do
    url = Application.get_env(application, module)[:service_url]

    if String.ends_with?(url, "/") do
      url
      |> String.slice(0..(String.length(url) - 2))
    else
      url
    end
  end

  @doc """
    Returns :ok if Application.get_env(:explorer, module)[:enabled] is true (module is enabled)
  """
  @spec check_enabled(atom) :: :ok | {:error, :disabled}
  def check_enabled(module) do
    if Application.get_env(:explorer, module)[:enabled] do
      :ok
    else
      {:error, :disabled}
    end
  end
end
