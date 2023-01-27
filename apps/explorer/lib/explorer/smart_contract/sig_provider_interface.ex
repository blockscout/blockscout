defmodule Explorer.SmartContract.SigProviderInterface do
  @moduledoc """
    Adapter for decoding events and function calls with https://github.com/blockscout/blockscout-rs/tree/main/sig-provider
  """

  alias Explorer.Utility.RustService
  alias HTTPoison.Response
  require Logger

  @request_error_msg "Error while sending request to sig-provider"

  def decode_function_call(input) do
    base_url = tx_input_decode_url()

    url =
      base_url
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(%{"txInput" => to_string(input)}))
      |> URI.to_string()

    http_get_request(url)
  end

  def decode_event(topics, data) do
    base_url = event_decode_url()

    url =
      base_url
      |> URI.parse()
      |> Map.put(
        :query,
        URI.encode_query(%{"topics" => topics |> Enum.reject(&is_nil/1) |> Enum.join(","), "data" => to_string(data)})
      )
      |> URI.to_string()

    http_get_request(url)
  end

  def http_get_request(url) do
    case HTTPoison.get(url) do
      {:ok, %Response{body: body, status_code: 200}} ->
        proccess_sig_provider_response(body)

      {:ok, %Response{body: body, status_code: _}} ->
        {:error, body}

      {:error, error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to sig-provider url: #{url}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  def proccess_sig_provider_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        proccess_sig_provider_response(decoded)

      _ ->
        {:error, body}
    end
  end

  def proccess_sig_provider_response(results) when is_list(results), do: {:ok, results}

  def proccess_sig_provider_response(other_responses), do: {:error, other_responses}

  def tx_input_decode_url, do: "#{base_api_url()}" <> "/function"

  def event_decode_url, do: "#{base_api_url()}" <> "/event"

  def base_api_url, do: "#{base_url()}" <> "/api/v1/abi"

  def base_url do
    RustService.base_url(__MODULE__)
  end

  def enabled?, do: Application.get_env(:explorer, __MODULE__)[:enabled]
end
