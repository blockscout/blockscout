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
          headers: [{String.t(), String.t()}],
          method: atom() | nil,
          platform_config: map() | nil,
          platform_id: String.t() | nil
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
  @reserved_param_types ~w(address chain_id chain_id_dependent)

  @config_url "https://raw.githubusercontent.com/blockscout/backend-configs/refs/heads/main/universal-proxy-config.json"

  @doc """
  Makes an API request to a third-party service using the provided proxy parameters.

  ## Parameters

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
  @spec api_request(map()) :: {any(), integer()}
  def api_request(proxy_params) do
    %{
      url: url,
      body: body,
      headers: headers,
      method: method,
      platform_config: platform_config,
      platform_id: platform_id
    } = parse_proxy_params(proxy_params)

    error_message =
      cond do
        !platform_config ->
          "Platform '#{platform_id}' not found in config or 'platforms' property doesn't exist at all"

        is_nil(url) ->
          "'base_url' is not defined for platform '#{platform_id}' or 'base' endpoint is not defined or 'base' endpoint path is not defined"

        is_nil(method) ->
          "Invalid HTTP request method ${method} for platform '#{platform_id}'"

        true ->
          "Unexpected error"
      end

    with {:invalid_config, false} <- {:invalid_config, is_nil(url)},
         {:invalid_config, false} <- {:invalid_config, is_nil(method)},
         {:ok, %Tesla.Env{status: status, body: body}} <-
           Tesla.request(
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

  @doc """
  Parses the proxy parameters and constructs an API request.

  This function takes a map of proxy parameters and uses the configuration
  to determine the platform-specific settings, such as the base URL, API key,
  HTTP method, and endpoint parameters. It returns a map representing the API
  request.

  ## Parameters

    - `proxy_params` (map): A map containing the proxy parameters, including
      the `platform_id` which is used to identify the platform configuration.

  ## Returns

    - A map representing the API request with the following keys:
      - `:url` (String.t | nil): The constructed URL for the API request.
      - `:body` (String.t): The body of the API request (currently an empty string).
      - `:headers` (list): A list of headers for the API request (currently empty).
      - `:method` (atom): The HTTP method for the API request (e.g., `:get`, `:post`).
      - `:platform_config` (map | nil): The configuration for the specified platform.
      - `:platform_id` (String.t | nil): The ID of the platform.

  ## Notes

    - If the platform configuration or required fields are missing, the `:url`
      in the returned map will be `nil`.
    - The function delegates further processing of the API key and endpoint
      parameters to `parse_endpoint_api_key/3` and `parse_endpoint_params/3`.
  """
  @spec parse_proxy_params(map()) :: api_request()
  def parse_proxy_params(proxy_params) do
    config = config()
    platform_id = proxy_params["platform_id"]

    platform_config = config["platforms"] && config["platforms"][platform_id]
    endpoint_params = (platform_config && platform_config["endpoints"]["base"]["params"]) || []
    endpoint_api_key = platform_config && platform_config["api_key"]

    method = parse_method(platform_config)

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
      url: raw_url,
      body: "",
      headers: [],
      method: method,
      platform_config: platform_config,
      platform_id: platform_id
    }
    |> parse_endpoint_api_key(endpoint_api_key, platform_id)
    |> parse_endpoint_params(endpoint_params, proxy_params)
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

  @spec parse_endpoint_api_key(api_request(), api_key() | nil, String.t() | nil) :: api_request()
  defp parse_endpoint_api_key(%{url: _url, headers: _headers} = map, nil, _platform_id), do: map

  defp parse_endpoint_api_key(
         %{url: url, headers: headers} = map,
         %{"location" => location, "param_name" => param_name} = endpoint_api_key,
         platform_id
       ) do
    api_key_env_name = String.upcase(platform_id) <> "_API_KEY"
    endpoint_api_key_value = System.get_env(api_key_env_name)

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

  defp parse_endpoint_api_key(map, _endpoint_api_key, _platform_id), do: map

  @spec parse_endpoint_params(api_request(), [endpoint_param()], map()) :: api_request()
  defp parse_endpoint_params(api_request_map, endpoint_params, proxy_params) do
    endpoint_params
    |> Enum.reduce(api_request_map, fn param, map ->
      case param do
        %{"location" => _location, "name" => _param_name, "value" => value} ->
          parse_param_location(map, param, value)

        %{"location" => _location, "type" => "chain_id_dependent", "mapping" => mapping} ->
          parse_param_location(map, param, mapping[proxy_params["chain_id"]])

        %{"location" => _location, "type" => param_type} ->
          parse_param_location(map, param, proxy_params[param_type])
      end
    end)
  end

  @spec parse_param_location(api_request(), endpoint_param(), String.t()) :: api_request()
  defp parse_param_location(
         %{body: body, url: url, headers: headers} = api_request_map,
         %{"location" => location} = params,
         value
       )
       when not is_nil(url) and not is_nil(value) do
    case location do
      "path" ->
        if value do
          Map.put(api_request_map, :url, String.replace(url, ":#{param_name(params)}", value))
        else
          api_request_map
        end

      "query" ->
        query_param_name = param_name(params)
        Map.put(api_request_map, :url, url <> "?#{query_param_name}=#{value}")

      "body" ->
        body_param_name = param_name(params)
        Map.put(api_request_map, :body, body <> "#{body_param_name}=#{value}&")

      "header" ->
        header_name = param_name(params)
        Map.put(api_request_map, :headers, [{header_name, value} | headers])

      _ ->
        api_request_map
    end
  end

  defp parse_param_location(%{body: _body, url: _url, headers: _headers} = api_request_map, _params, _value),
    do: api_request_map

  defp param_name(params) do
    with true <- params["type"] in @reserved_param_types,
         true <- not is_nil(params["name"]) do
      params["name"]
    else
      _ -> params["type"]
    end
  end

  defp config do
    case Tesla.get(@config_url) do
      {:ok, %Tesla.Env{status: 200, body: config_string}} ->
        {:ok, config} = Jason.decode(config_string)
        config

      _ ->
        %{}
    end
  end
end
