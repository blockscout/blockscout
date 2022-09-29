defmodule BlockScoutWeb.APIDocsView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.LayoutView
  alias Explorer

  def action_tile_id(module, action) do
    "#{module}-#{action}"
  end

  def query_params(module, action) do
    module_and_action(module, action) <> Enum.join(required_params(action))
  end

  def input_placeholder(param) do
    "#{param.key} - #{param.description}"
  end

  def model_type_definition(definition) when is_binary(definition) do
    definition
  end

  def model_type_definition(definition_func) when is_function(definition_func, 1) do
    coin = Explorer.coin()
    definition_func.(coin)
  end

  defp module_and_action(module, action) do
    "?module=<strong>#{module}</strong>&action=<strong>#{action.name}</strong>"
  end

  defp required_params(action) do
    Enum.map(action.required_params, fn param ->
      "&#{param.key}=" <> "{<strong>#{param.placeholder}</strong>}"
    end)
  end

  def blockscout_url(set_path) when set_path == false do
    url_params = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url]
    host = url_params[:host]

    scheme = Keyword.get(url_params, :scheme, "http")

    if host != "localhost" do
      "#{scheme}://#{host}"
    else
      port = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:http][:port]
      "#{scheme}://#{host}:#{to_string(port)}"
    end
  end

  def blockscout_url(set_path, is_api) when set_path == true do
    url_params = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url]
    host = url_params[:host]

    path =
      if is_api do
        url_params[:api_path]
      else
        url_params[:path]
      end

    scheme = Keyword.get(url_params, :scheme, "http")

    if host != "localhost" do
      "#{scheme}://#{host}#{path}"
    else
      port = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:http][:port]
      "#{scheme}://#{host}:#{to_string(port)}"
    end
  end

  def api_url do
    is_api = true
    set_path = true

    set_path
    |> blockscout_url(is_api)
    |> Path.join("api")
  end

  def eth_rpc_api_url do
    is_api = true
    set_path = true

    set_path
    |> blockscout_url(is_api)
    |> Path.join("api/eth-rpc")
  end
end
