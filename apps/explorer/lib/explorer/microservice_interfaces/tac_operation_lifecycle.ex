defmodule Explorer.MicroserviceInterfaces.TACOperationLifecycle do
  @moduledoc """
    Interface to interact with Tac Operation Lifecycle Service (https://github.com/blockscout/blockscout-rs/tree/main/tac-operation-lifecycle)
  """

  alias Explorer.HttpClient
  alias Explorer.Utility.Microservice
  require Logger

  @request_error_msg "Error while sending request to Tac Operation Lifecycle Service"

  @spec get_operations_by_id_or_sender_or_transaction_hash(String.t(), nil | map()) ::
          {:ok, %{items: [map()], next_page_params: map() | nil}}
          | {:error, :disabled | :not_found | Jason.DecodeError.t() | String.t()}
  def get_operations_by_id_or_sender_or_transaction_hash(param, page_params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params =
        %{
          "q" => param
        }
        |> Map.merge(page_params || %{})

      operations_quick_search_url()
      |> http_get_request(query_params)
      |> case do
        {:ok, %{"items" => operations, "next_page_params" => next_page_params}} ->
          {:ok, %{items: operations, next_page_params: next_page_params}}

        error ->
          error
      end
    end
  end

  defp http_get_request(url, query_params) do
    case HttpClient.get(url, [], params: query_params) do
      {:ok, %{body: body, status_code: 200}} ->
        case Jason.decode(body) do
          {:ok, decoded_body} ->
            {:ok, decoded_body}

          error ->
            log_error(error)
            {:error, error}
        end

      {:ok, %{body: _body, status_code: 404}} ->
        {:error, :not_found}

      {_, error} ->
        log_error(error)
        {:error, @request_error_msg}
    end
  end

  defp log_error(error) do
    old_truncate = Application.get_env(:logger, :truncate)
    Logger.configure(truncate: :infinity)

    Logger.error(fn ->
      [
        "#{@request_error_msg}: ",
        inspect(error, limit: :infinity, printable_limit: :infinity)
      ]
    end)

    Logger.configure(truncate: old_truncate)
  end

  defp operations_quick_search_url do
    "#{base_url()}/tac/operations"
  end

  defp base_url do
    "#{Microservice.base_url(__MODULE__)}/api/v1"
  end
end
