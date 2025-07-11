defmodule EthereumJSONRPC.HTTP do
  @moduledoc """
  JSONRPC over HTTP
  """

  alias EthereumJSONRPC.{DecodeError, Transport}
  alias EthereumJSONRPC.Utility.{CommonHelper, EndpointAvailabilityObserver}

  require Logger

  import EthereumJSONRPC, only: [sanitize_id: 1]

  @behaviour Transport

  @doc """
  Sends JSONRPC request encoded as `t:iodata/0` to `url` with `options`
  """
  @callback json_rpc(url :: String.t(), json :: iodata(), headers :: [{String.t(), String.t()}], options :: term()) ::
              {:ok, %{body: body :: String.t(), status_code: status_code :: pos_integer()}}
              | {:error, reason :: term}

  @impl Transport

  def json_rpc(%{method: method} = request, options) when is_map(request) do
    json = encode_json(request)
    http = Keyword.fetch!(options, :http)
    {url_type, url} = url(options, method)
    http_options = Keyword.fetch!(options, :http_options)

    with {:ok, %{body: body, status_code: code}} <- http.json_rpc(url, json, headers(), http_options),
         {:ok, json} <-
           decode_json(request: [url: url, body: json, headers: headers()], response: [status_code: code, body: body]),
         {:ok, response} <- handle_response(json, code) do
      {:ok, response}
    else
      error ->
        increment_error_count(url, url_type, options)
        error
    end
  end

  def json_rpc([batch | _] = chunked_batch_request, options) when is_list(batch) do
    chunked_json_rpc(chunked_batch_request, options, [])
  end

  def json_rpc(batch_request, options) when is_list(batch_request) do
    chunked_json_rpc([batch_request], options, [])
  end

  defp chunked_json_rpc([], _options, decoded_response_bodies) when is_list(decoded_response_bodies) do
    list =
      decoded_response_bodies
      |> Enum.reverse()
      |> List.flatten()
      |> Enum.map(&standardize_response/1)

    {:ok, list}
  end

  # JSONRPC 2.0 standard says that an empty batch (`[]`) returns an empty response (`""`), but an empty response isn't
  # valid JSON, so instead act like it returns an empty list (`[]`)
  defp chunked_json_rpc([[] | tail], options, decoded_response_bodies) do
    chunked_json_rpc(tail, options, decoded_response_bodies)
  end

  defp chunked_json_rpc([[%{method: method} | _] = batch | tail] = chunks, options, decoded_response_bodies)
       when is_list(tail) and is_list(decoded_response_bodies) do
    http = Keyword.fetch!(options, :http)
    {url_type, url} = url(options, method)
    http_options = Keyword.fetch!(options, :http_options)

    json = encode_json(batch)

    case http.json_rpc(url, json, headers(), http_options) do
      {:ok, %{status_code: status_code} = response} when status_code in [413, 504] ->
        rechunk_json_rpc(chunks, options, response, decoded_response_bodies)

      {:ok, %{body: body, status_code: status_code}} ->
        case decode_json(
               request: [url: url, body: json, headers: headers()],
               response: [status_code: status_code, body: body]
             ) do
          {:ok, decoded_body} ->
            chunked_json_rpc(tail, options, [decoded_body | decoded_response_bodies])

          error ->
            increment_error_count(url, url_type, options)
            error
        end

      {:error, :timeout} ->
        rechunk_json_rpc(chunks, options, :timeout, decoded_response_bodies)

      {:error, _} = error ->
        increment_error_count(url, url_type, options)
        error
    end
  end

  defp rechunk_json_rpc([batch | tail], options, response, decoded_response_bodies) do
    case length(batch) do
      # it can't be made any smaller
      1 ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "413 Request Entity Too Large returned from single request batch. Cannot shrink batch further. ",
            "The actual batched request was ",
            "#{inspect(batch)}. ",
            "The actual response of the method was ",
            "#{inspect(response)}."
          ]
        end)

        Logger.configure(truncate: old_truncate)

        {:error, response}

      batch_size ->
        split_size = div(batch_size, 2)
        {first_chunk, second_chunk} = Enum.split(batch, split_size)
        new_chunks = [first_chunk, second_chunk | tail]
        chunked_json_rpc(new_chunks, options, decoded_response_bodies)
    end
  end

  defp encode_json(data), do: Jason.encode_to_iodata!(data)

  defp decode_json(named_arguments) when is_list(named_arguments) do
    response = Keyword.fetch!(named_arguments, :response)
    response_body = Keyword.fetch!(response, :body)

    with {:error, _} <- Jason.decode(response_body) do
      case Keyword.fetch!(response, :status_code) do
        # CloudFlare protected server return HTML errors for 502, so the JSON decode will fail
        502 ->
          request_url =
            named_arguments
            |> Keyword.fetch!(:request)
            |> Keyword.fetch!(:url)

          {:error, {:bad_gateway, request_url}}

        _ ->
          named_arguments
          |> DecodeError.exception()
          |> DecodeError.message()
          |> Logger.error()

          request_url =
            named_arguments
            |> Keyword.fetch!(:request)
            |> Keyword.fetch!(:url)

          {:error, {:bad_response, request_url}}
      end
    end
  end

  defp handle_response(resp, 200) do
    case resp do
      %{"error" => error} -> {:error, standardize_error(error)}
      %{"result" => result} -> {:ok, result}
    end
  end

  defp handle_response(resp, _status) do
    {:error, resp}
  end

  defp increment_error_count(url, url_type, options) do
    named_arguments = [transport: __MODULE__, transport_options: Keyword.delete(options, :method_to_url)]
    EndpointAvailabilityObserver.inc_error_count(url, named_arguments, url_type)
  end

  @doc """
    Standardizes responses to adhere to the JSON-RPC 2.0 standard.

    This function adjusts responses to conform to JSON-RPC 2.0, ensuring the keys are atom-based
    and that 'id', 'jsonrpc', 'result', and 'error' fields meet the protocol's requirements.
    It also validates the mutual exclusivity of 'result' and 'error' fields within a response.

    ## Parameters
    - `unstandardized`: A map representing the response with string keys.

    ## Returns
    - A standardized map with atom keys and fields aligned with the JSON-RPC 2.0 standard, including
      handling of possible mutual exclusivity errors between 'result' and 'error' fields.
  """
  @spec standardize_response(map()) :: %{
          :id => nil | non_neg_integer(),
          :jsonrpc => binary(),
          optional(:error) => %{:code => integer(), :message => binary(), optional(:data) => any()},
          optional(:result) => any()
        }
  def standardize_response(%{"jsonrpc" => "2.0" = jsonrpc} = unstandardized) do
    # Avoid extracting `id` directly in the function declaration. Some endpoints
    # do not adhere to standards and may omit the `id` in responses related to
    # error scenarios. Consequently, the function call would fail during input
    # argument matching.

    # Nethermind return string ids
    id = sanitize_id(unstandardized["id"])

    standardized = %{jsonrpc: jsonrpc, id: id}

    case {id, unstandardized} do
      {_id, %{"result" => _, "error" => _}} ->
        raise ArgumentError,
              "result and error keys are mutually exclusive in JSONRPC 2.0 response objects, but got #{inspect(unstandardized)}"

      {nil, %{"result" => error}} ->
        Map.put(standardized, :error, standardize_error(error))

      {_id, %{"result" => result}} ->
        Map.put(standardized, :result, result)

      {_id, %{"error" => error}} ->
        Map.put(standardized, :error, standardize_error(error))
    end
  end

  @doc """
    Standardizes error responses to adhere to the JSON-RPC 2.0 standard.

    This function converts a map containing error information into a format compliant
    with the JSON-RPC 2.0 specification. It ensures the keys are atom-based and checks
    for the presence of optional 'data' field, incorporating it if available.

    ## Parameters
    - `unstandardized`: A map representing the error with string keys: "code", "message"
                        and "data" (optional).

    ## Returns
    - A standardized map with keys as atoms and fields aligned with the JSON-RPC 2.0 standard.
  """
  @spec standardize_error(map()) :: %{:code => integer(), :message => binary(), optional(:data) => any()}
  def standardize_error(%{"code" => code, "message" => message} = unstandardized)
      when is_integer(code) and is_binary(message) do
    standardized = %{code: code, message: message}

    case Map.fetch(unstandardized, "data") do
      {:ok, data} -> Map.put(standardized, :data, data)
      :error -> standardized
    end
  end

  defp url(options, method) when is_list(options) and is_binary(method) do
    with {:ok, method_to_url} <- Keyword.fetch(options, :method_to_url),
         {:ok, method_atom} <- to_existing_atom(method),
         {:ok, url_type} <- Keyword.fetch(method_to_url, method_atom) do
      {url_type, CommonHelper.get_available_url(options, url_type)}
    else
      _ ->
        {:http, CommonHelper.get_available_url(options, :http)}
    end
  end

  defp to_existing_atom(string) do
    {:ok, String.to_existing_atom(string)}
  rescue
    ArgumentError ->
      :error
  end

  defp headers do
    gzip_enabled? = Application.get_env(:ethereum_jsonrpc, __MODULE__)[:gzip_enabled?]

    additional_headers =
      if gzip_enabled? do
        [{"Accept-Encoding", "gzip"}]
      else
        []
      end

    Application.get_env(:ethereum_jsonrpc, __MODULE__)[:headers] ++ additional_headers
  end
end
