defmodule Explorer.Utility.RustService do
  def base_url(module) do
    url = Application.get_env(:explorer, module)[:service_url]

    if String.ends_with?(url, "/") do
      url
      |> String.slice(0..(String.length(url) - 2))
    else
      url
    end
  end
end
