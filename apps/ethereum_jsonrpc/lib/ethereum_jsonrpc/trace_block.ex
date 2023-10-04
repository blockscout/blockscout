defmodule EthereumJSONRPC.TraceBlock do
  @moduledoc """
  Functions for processing the data from `trace_block` JSON RPC method.
  """

  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, request: 1]

  @spec fetch_block_internal_transactions(
          [non_neg_integer()],
          EthereumJSONRPC.json_rpc_named_arguments(),
          EthereumJSONRPC.RSK.Traces
        ) :: {:error, any} | {:ok, any}
  def fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments, traces_module) do
    id_to_params = id_to_params(block_numbers)

    with {:ok, responses} <-
           id_to_params
           |> trace_block_requests()
           |> json_rpc(json_rpc_named_arguments) do
      trace_block_responses_to_internal_transactions_params(responses, id_to_params, traces_module)
    end
  end

  defp trace_block_requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, block_number} ->
      trace_block_request(%{id: id, block_number: block_number})
    end)
  end

  defp trace_block_request(%{id: id, block_number: block_number}) do
    request(%{id: id, method: "trace_block", params: [integer_to_quantity(block_number)]})
  end

  defp trace_block_responses_to_internal_transactions_params(responses, id_to_params, traces_module) do
    with {:ok, traces} <- trace_block_responses_to_traces(responses, id_to_params) do
      params =
        traces
        |> traces_module.to_elixir()
        |> traces_module.elixir_to_params()

      {:ok, params}
    end
  end

  defp trace_block_responses_to_traces(responses, id_to_params) do
    responses
    |> EthereumJSONRPC.sanitize_responses(id_to_params)
    |> Enum.map(&trace_block_response_to_traces(&1, id_to_params))
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> case do
      %{error: reasons} ->
        {:error, reasons}

      %{ok: traces_list} ->
        traces =
          traces_list
          |> List.flatten()

        {:ok, traces}

      %{} ->
        {:ok, []}
    end
  end

  defp trace_block_response_to_traces(%{result: results}, _id_to_params)
       when is_list(results) do
    annotated_traces =
      results
      |> Enum.scan(%{"index" => -1}, fn trace, %{"index" => internal_transaction_index} ->
        internal_transaction_index = if trace["traceAddress"] == [], do: 0, else: internal_transaction_index + 1

        trace
        |> Map.put("index", internal_transaction_index)
      end)

    {:ok, annotated_traces}
  end

  defp trace_block_response_to_traces(%{id: id, error: error}, id_to_params)
       when is_map(id_to_params) do
    block_number = Map.fetch!(id_to_params, id)

    annotated_error =
      Map.put(error, :data, %{
        "blockNumber" => block_number
      })

    {:error, annotated_error}
  end
end
