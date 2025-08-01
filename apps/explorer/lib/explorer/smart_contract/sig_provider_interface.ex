defmodule Explorer.SmartContract.SigProviderInterface do
  @moduledoc """
    Adapter for decoding events and function calls with https://github.com/blockscout/blockscout-rs/tree/main/sig-provider
  """

  alias Explorer.HttpClient
  alias Explorer.Utility.Microservice
  require Logger

  @request_error_msg "Error while sending request to sig-provider"
  @post_timeout :timer.seconds(60)

  @spec decode_function_call(map()) :: {:ok, list()} | {:error, any}
  def decode_function_call(input) do
    base_url = transaction_input_decode_url()

    url =
      base_url
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(%{"txInput" => to_string(input)}))
      |> URI.to_string()

    http_get_request(url)
  end

  @spec decode_event([String.t()], String.t()) :: {:ok, list()} | {:error, any}
  def decode_event(topics, data) do
    base_url = decode_event_url()

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

  @doc """
  Decodes a batch of events by sending a POST request to /api/v1/abi/events:batch-get endpoint of the Sig-provider microservice.

  ## Parameters

    - `input`: A list of maps, where each map represents an event with the following keys:
      - `:topics` (String.t()): The topics associated with the event.
      - `:data` (String.t()): The data associated with the event.

  ## Returns

    - The response from the HTTP POST request.

  ## Example

      iex> decode_events_in_batch([
      ...>   %{topics: "topic1,topic2", data: "data1"},
      ...>   %{topics: "topic3,topic4", data: "data2"}
      ...> ])
      {:ok, response}

  """
  @spec decode_events_in_batch([
          %{
            :topics => String.t(),
            :data => String.t()
          }
        ]) :: {:ok, [map]} | {:error, any}
  def decode_events_in_batch(input) do
    url = decode_events_batch_url()

    body = %{
      :requests => input
    }

    http_post_request(url, body)
  end

  defp http_get_request(url) do
    case HttpClient.get(url) do
      {:ok, %{body: body, status_code: 200}} ->
        process_sig_provider_response(body)

      {:ok, %{body: body, status_code: _}} ->
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

  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HttpClient.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %{body: body, status_code: 200}} ->
        body |> Jason.decode()

      error ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to sig-provider url: #{url}, body: #{inspect(body, limit: :infinity, printable_limit: :infinity)}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  defp process_sig_provider_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        process_sig_provider_response(decoded)

      _ ->
        {:error, body}
    end
  end

  defp process_sig_provider_response(results) when is_list(results), do: {:ok, results}

  defp process_sig_provider_response(other_responses), do: {:error, other_responses}

  defp transaction_input_decode_url, do: "#{base_api_url()}" <> "/function"

  defp decode_event_url, do: "#{base_api_url()}" <> "/event"

  # cspell:disable
  defp decode_events_batch_url, do: "#{base_api_url()}" <> "/events%3Abatch-get"
  # cspell:enable

  def base_api_url, do: "#{base_url()}" <> "/api/v1/abi"

  def base_url do
    Microservice.base_url(__MODULE__)
  end

  def enabled?, do: Application.get_env(:explorer, __MODULE__)[:enabled]
end
