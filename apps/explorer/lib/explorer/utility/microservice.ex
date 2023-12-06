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
end
