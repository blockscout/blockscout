defmodule Utils.Helper do
  @moduledoc """
  This module contains helper functions for the entire application.
  """

  @doc """
  Retrieves the host URL for the application.

  ## Returns

  - A string containing the host URL for the application.
  """
  @spec instance_url :: URI.t()
  def instance_url do
    %URI{scheme: scheme(), host: host(), port: port(), path: path()}
  end

  defp url_params do
    Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url]
  end

  defp scheme do
    Keyword.get(url_params(), :scheme, "http")
  end

  defp host do
    url_params()[:host]
  end

  defp port do
    url_params()[:http][:port]
  end

  defp path do
    raw_path = url_params()[:path]

    if raw_path |> String.ends_with?("/") do
      raw_path |> String.slice(0..-2//1)
    else
      raw_path
    end
  end
end
