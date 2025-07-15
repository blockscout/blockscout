defmodule Explorer.HttpClient do
  @moduledoc false

  def get(url, headers \\ [], options \\ []) do
    adapter().get(url, headers, options)
  end

  def get!(url, headers \\ [], options \\ []) do
    adapter().get!(url, headers, options)
  end

  def post(url, body, headers \\ [], options \\ []) do
    adapter().post(url, body, headers, options)
  end

  def head(url, headers \\ [], options \\ []) do
    adapter().head(url, headers, options)
  end

  def request(method, url, headers, body, options \\ []) do
    adapter().request(method, url, headers, body, options)
  end

  defp adapter do
    Application.get_env(:explorer, :http_client)
  end
end
