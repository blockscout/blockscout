defmodule Explorer.MicroserviceInterfaces.TACOperationLifecycle do
  @moduledoc """
    Interface to interact with Tac Operation Lifecycle Service (https://github.com/blockscout/blockscout-rs/tree/main/tac-operation-lifecycle)
  """

  alias Explorer.Utility.Microservice
  alias HTTPoison.Response
  require Logger

  @request_error_msg "Error while sending request to Tac Operation Lifecycle Service"

  @doc """
  Retrieves operation details from the TAC Operation Lifecycle Service by operation ID.

  Fetches complete operation information including type, timestamp, sender, and
  status history from the TAC Operation Lifecycle Service. The function first
  checks if the microservice is enabled before making the request.

  ## Parameters
  - `operation_id`: Unique identifier for the operation to retrieve

  ## Returns
  - `{:ok, map()}`: Operation details containing operation_id, type, timestamp,
    sender, and status_history if the request succeeds
  - `{:error, :disabled}`: If the TAC Operation Lifecycle microservice is disabled
  - `{:error, :not_found}`: If the operation with the given ID does not exist
  - `{:error, String.t()}`: Error message if the request fails
  """
  @spec get_operation_by_id(String.t()) :: {:ok, map()} | {:error, :disabled | :not_found}
  def get_operation_by_id(operation_id) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params = %{}

      operation_id
      |> operation_by_id_url()
      |> http_get_request(query_params)
    end
  end

  defp http_get_request(url, query_params) do
    case HTTPoison.get(url, [], params: query_params) do
      {:ok, %Response{body: body, status_code: 200}} ->
        Jason.decode(body)

      {:ok, %Response{body: _body, status_code: 404}} ->
        {:error, :not_found}

      {_, error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "#{@request_error_msg}: #{url}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  defp operation_by_id_url(operation_id) do
    "#{base_url()}/tac/operations/#{operation_id}"
  end

  defp base_url do
    "#{Microservice.base_url(__MODULE__)}/api/v1"
  end
end
