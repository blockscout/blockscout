defmodule BlockScoutWeb.TestApiSchemaAssertions do
  @moduledoc """
  Test helper that automatically validates JSON responses against the OpenAPI schema
  for every GET request to `/api/*` endpoints.

  It wraps `Phoenix.ConnTest.json_response/2` to perform schema validation using
  `OpenApiSpex.TestAssertions.assert_schema/3` based on the current request path,
  HTTP method and status code.
  """

  # import Phoenix.ConnTest, except: [json_response: 2]

  require Logger
  alias OpenApiSpex.{Operation, PathItem}

  @spec json_response(Plug.Conn.t(), non_neg_integer()) :: map() | list()
  def json_response(%Plug.Conn{} = conn, status_code) when is_integer(status_code) do
    json = Phoenix.ConnTest.json_response(conn, status_code)

    maybe_assert_schema(conn, status_code, json)

    json
  end

  defp maybe_assert_schema(%Plug.Conn{method: "GET", request_path: request_path} = _conn, status_code, json)
       when is_integer(status_code) and is_binary(request_path) do
    if String.starts_with?(request_path, "/api/") do
      spec = BlockScoutWeb.ApiSpec.spec()

      case find_path_item(spec, request_path) do
        {:ok, %PathItem{} = path_item} ->
          case Map.get(path_item, :get) do
            %Operation{} = operation ->
              case find_response_schema(operation, status_code) do
                {:ok, schema} ->
                  Logger.info(
                    "Validated response against schema for path: #{request_path} and status code: #{status_code}"
                  )

                  OpenApiSpex.TestAssertions.assert_raw_schema(json, schema, spec)

                :error ->
                  Logger.warning("No schema found for path: #{request_path} and status code: #{status_code}")
                  :ok
              end

            _ ->
              :ok
          end

        :error ->
          Logger.warning("No schema found for path: #{request_path}")
          :ok
      end
    end
  end

  defp maybe_assert_schema(_conn, _status_code, _json), do: :ok

  defp find_path_item(%{paths: paths} = _spec, request_path) when is_map(paths) do
    api_relative = strip_api_prefix(request_path)

    with {:ok, {_, path_item}} <- match_template_path(paths, api_relative) do
      {:ok, path_item}
    else
      _ -> :error
    end
  end

  defp strip_api_prefix("/api" <> rest), do: rest
  defp strip_api_prefix(path), do: path

  defp match_template_path(paths_map, actual_path) do
    actual_segments = split_path(actual_path)

    Enum.find_value(paths_map, fn {template_path, %PathItem{} = item} ->
      template_segments = split_path(template_path)

      if segments_match?(template_segments, actual_segments) do
        {:ok, {template_path, item}}
      else
        false
      end
    end) || :error
  end

  defp split_path(path) when is_binary(path) do
    path
    |> String.split("?", parts: 2)
    |> hd()
    |> String.split("/", trim: true)
  end

  defp segments_match?(template_segments, actual_segments) when length(template_segments) == length(actual_segments) do
    Enum.zip(template_segments, actual_segments)
    |> Enum.all?(fn {t, a} -> dynamic_segment?(t) or t == a end)
  end

  defp segments_match?(_template_segments, _actual_segments), do: false

  defp dynamic_segment?(segment) when is_binary(segment) do
    String.starts_with?(segment, "{") and String.ends_with?(segment, "}")
  end

  defp find_response_schema(%Operation{responses: responses}, status_code) when is_map(responses) do
    key = Integer.to_string(status_code)

    response = Map.get(responses, key) || Map.get(responses, status_code) || Map.get(responses, "default")

    case response do
      %OpenApiSpex.Response{content: %{"application/json" => %OpenApiSpex.MediaType{schema: schema}}} ->
        {:ok, schema}

      %OpenApiSpex.Reference{} = ref ->
        {:ok, ref}

      _ ->
        :error
    end
  end
end
