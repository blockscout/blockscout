defmodule Explorer.Visualize.Sol2uml do
  @moduledoc """
    Adapter for sol2uml visualizer with https://github.com/blockscout/blockscout-rs/blob/main/visualizer
  """
  alias Explorer.Utility.RustService
  alias HTTPoison.Response
  require Logger

  @post_timeout 60_000
  @request_error_msg "Error while sending request to visualizer microservice"

  def visualize_contracts(body) do
    http_post_request(visualize_contracts_url(), body)
  end

  def http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %Response{body: body, status_code: 200}} ->
        process_visualizer_response(body)

      {:ok, %Response{body: body, status_code: status_code}} ->
        Logger.error(fn -> ["Invalid status code from visualizer: #{status_code}. body: ", inspect(body)] end)
        {:error, "failed to visualize contract"}

      {:error, error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to visualizer microservice. url: #{url}, body: #{inspect(body, limit: :infinity, printable_limit: :infinity)}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  def process_visualizer_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        process_visualizer_response(decoded)

      _ ->
        {:error, body}
    end
  end

  def process_visualizer_response(%{"svg" => svg}) do
    {:ok, svg}
  end

  def process_visualizer_response(other), do: {:error, other}

  def visualize_contracts_url, do: "#{base_api_url()}" <> "/solidity:visualize-contracts"

  def base_api_url, do: "#{base_url()}" <> "/api/v1"

  def base_url do
    RustService.base_url(__MODULE__)
  end

  def enabled?, do: Application.get_env(:explorer, __MODULE__)[:enabled]
end
