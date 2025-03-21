defmodule Explorer.ThirdPartyIntegrations.UniversalProxy do
  @moduledoc """
  Module for universal proxying 3dparty API endpoints
  """
  use Tesla

  alias Explorer.Helper

  @recv_timeout 60_000

  @type api_request :: %{
          url: String.t() | nil,
          body: String.t(),
          headers: [{String.t(), String.t()}]
        }

  @type api_key :: %{
          location: String.t(),
          param_name: String.t()
        }

  @type endpoint_param :: %{
          location: String.t(),
          param_name: String.t(),
          param_value: String.t()
        }

  @allowed_methods [:get, :post, :put, :patch, :delete]

  @config_url "https://raw.githubusercontent.com/blockscout/backend-configs/refs/heads/main/universal-proxy-config.json"

  @doc """
  Makes an API request to a third-party service using the provided proxy parameters.

  ## Parameters

    - `_conn`: The connection object (not used in this function).
    - `proxy_params`: A map containing the parameters for the proxy request. It must include the "platform" key to identify the target platform.

  ## Configuration

  The function relies on a configuration map that defines platform-specific settings. The configuration should include:
    - `platforms`: A map where each key is a platform name and the value is a map with platform-specific settings.
      - `base_url`: The base URL for the platform's API.
      - `endpoints`: A map of endpoint configurations, including:
        - `base`: A map with `path` and optional `params`.
      - `api_key`: The API key for the platform, if required.

  ## Behavior

  1. Retrieves the platform-specific configuration based on the `platform` key in `proxy_params`.
  2. Constructs the request URL using the `base_url` and `base` endpoint path.
  3. Parses and applies any API key and endpoint parameters.
  4. Sends the HTTP request using the Tesla library with the specified method, URL, headers, and body.

  ## Returns

    - On success: A tuple `{decoded_body, status}` where:
      - `decoded_body`: The JSON-decoded response body.
      - `status`: The HTTP status code of the response.
    - On failure due to invalid configuration: A tuple `{"Invalid config: <error_message>", 422}`.
    - On unexpected errors: A tuple `{"Unexpected error when calling proxied endpoint", 500}`.

  ## Errors

  The function handles the following error scenarios:
    - Missing or invalid platform configuration.
    - Missing `base_url`, `base` endpoint, or `base` endpoint path.
    - Invalid or unsupported HTTP method.
    - Unexpected errors during the HTTP request.

  ## Notes

    - The function uses the `Tesla` library with the `Tesla.Adapter.Mint` adapter.
    - A timeout is applied to the request using the `@recv_timeout` module attribute.
  """
  @spec api_request(Plug.Conn.t(), map()) :: {any(), integer()}
  def api_request(_conn, proxy_params) do
    config = config()
    platform = proxy_params["platform"]

    platform_config = config["platforms"] && config["platforms"][platform]

    method = parse_method(platform_config)
    endpoint_params = (platform_config && platform_config["endpoints"]["base"]["params"]) || []
    endpoint_api_key = platform_config && platform_config["api_key"]

    raw_url =
      with true <- not is_nil(platform_config),
           true <- not is_nil(platform_config["base_url"]),
           endpoints = platform_config["endpoints"],
           true <- not is_nil(endpoints),
           base_endpoint = endpoints["base"],
           true <- not is_nil(base_endpoint),
           true <- not is_nil(base_endpoint["path"]) do
        platform_config["base_url"] <> base_endpoint["path"]
      else
        _ ->
          nil
      end

    %{
      url: url,
      body: body,
      headers: headers
    } =
      %{
        url: raw_url,
        body: "",
        headers: []
      }
      |> parse_endpoint_api_key(endpoint_api_key)
      |> parse_endpoint_params(endpoint_params, proxy_params)

    client = Tesla.client([], Tesla.Adapter.Mint)

    error_message =
      cond do
        !platform_config ->
          "Platform '#{platform}' not found in config or 'platforms' property doesn't exist at all"

        is_nil(url) ->
          "'base_url' is not defined for platform '#{platform}' or 'base' endpoint is not defined or 'base' endpoint path is not defined"

        is_nil(method) ->
          "Invalid HTTP request method ${method} for platform '#{platform}'"

        true ->
          "Unexpected error"
      end

    with {:invalid_config, false} <- {:invalid_config, is_nil(url)},
         {:invalid_config, false} <- {:invalid_config, is_nil(method)},
         {:ok, %Tesla.Env{status: status, body: body}} <-
           Tesla.request(client,
             method: method,
             url: url,
             headers: headers,
             body: body,
             opts: [timeout: @recv_timeout, adapter: [protocols: [:http1]]]
           ) do
      {Helper.decode_json(body), status}
    else
      {:invalid_config, true} ->
        {"Invalid config: #{error_message}", 422}

      _ ->
        {"Unexpected error when calling proxied endpoint", 500}
    end
  end

  @spec parse_method(map() | nil) :: atom() | nil
  defp parse_method(nil), do: nil

  defp parse_method(platform_config) do
    raw_method = String.to_existing_atom(String.downcase(platform_config["endpoints"]["base"]["method"]))

    if raw_method in @allowed_methods do
      raw_method
    else
      nil
    end
  end

  @spec parse_endpoint_api_key(api_request(), api_key() | nil) :: api_request()
  defp parse_endpoint_api_key(%{url: _url, headers: _headers} = map, nil), do: map

  defp parse_endpoint_api_key(
         %{url: url, headers: headers} = map,
         %{"location" => location, "param_name" => param_name} = endpoint_api_key
       ) do
    endpoint_api_key_value = Application.get_env(:explorer, Explorer.ThirdPartyIntegrations.Xname)[:api_key]

    case location do
      "header" ->
        if endpoint_api_key["prefix"] do
          Map.put(map, :headers, [
            {param_name, "#{endpoint_api_key["prefix"]} #{endpoint_api_key_value}"} | headers
          ])
        else
          Map.put(map, :headers, [{param_name, endpoint_api_key_value} | headers])
        end

      "query" ->
        Map.put(map, :url, url <> "?#{param_name}=#{endpoint_api_key_value}")

      _ ->
        map
    end
  end

  defp parse_endpoint_api_key(map, _endpoint_api_key), do: map

  @spec parse_endpoint_params(api_request(), [endpoint_param()], map()) :: api_request()
  defp parse_endpoint_params(api_request_map, endpoint_params, proxy_params) do
    endpoint_params
    |> Enum.reduce(api_request_map, fn param, map ->
      case param do
        %{"location" => _location, "name" => _param_name, "value" => value} ->
          parse_param_location(map, param, value)

        %{"location" => _location, "name" => param_name} ->
          parse_param_location(map, param, proxy_params[param_name])
      end
    end)
  end

  @spec parse_param_location(api_request(), endpoint_param(), String.t()) :: api_request()
  defp parse_param_location(%{body: body, url: url, headers: headers} = api_request_map, param, value)
       when not is_nil(url) do
    case param["location"] do
      "path" ->
        Map.put(api_request_map, :url, String.replace(url, ":#{param["name"]}", value))

      "query" ->
        Map.put(api_request_map, :url, url <> "?#{param["name"]}=#{value}")

      "body" ->
        Map.put(api_request_map, :body, body <> "#{param["name"]}=#{value}&")

      "header" ->
        Map.put(api_request_map, :headers, [{param["name"], value} | headers])

      _ ->
        api_request_map
    end
  end

  defp parse_param_location(%{body: _body, url: nil, headers: _headers} = api_request_map, _param, _value),
    do: api_request_map

  defp config do
    config_string = HTTPoison.get!(@config_url).body

    {:ok, config} = Jason.decode(config_string)
    config
  end
end
