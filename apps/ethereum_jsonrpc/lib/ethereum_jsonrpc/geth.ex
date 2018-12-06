defmodule EthereumJSONRPC.Geth do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Geth](https://github.com/ethereum/go-ethereum/wiki/geth).
  """

  import EthereumJSONRPC, only: [id_to_params: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.Geth.Calls

  @behaviour EthereumJSONRPC.Variant

  @doc """
  Block reward contract beneficiary fetching is not supported currently for Geth.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_beneficiaries(_block_range, _json_rpc_named_arguments), do: :ignore

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    id_to_params = id_to_params(transactions_params)

    with {:ok, responses} <-
           id_to_params
           |> debug_trace_transaction_requests()
           |> json_rpc(json_rpc_named_arguments) do
      debug_trace_transaction_responses_to_internal_transactions_params(responses, id_to_params)
    end
  end

  @doc """
  Pending transaction fetching is not supported currently for Geth.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_pending_transactions(_json_rpc_named_arguments), do: :ignore

  defp debug_trace_transaction_requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{hash_data: hash_data}} ->
      debug_trace_transaction_request(%{id: id, hash_data: hash_data})
    end)
  end

  @tracer_path "priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js"
  @external_resource @tracer_path
  @tracer File.read!(@tracer_path)

  defp debug_trace_transaction_request(%{id: id, hash_data: hash_data}) do
    request(%{id: id, method: "debug_traceTransaction", params: [hash_data, %{tracer: @tracer}]})
  end

  defp debug_trace_transaction_responses_to_internal_transactions_params(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    responses
    |> Enum.map(&debug_trace_transaction_response_to_internal_transactions_params(&1, id_to_params))
    |> reduce_internal_transactions_params()
  end

  defp debug_trace_transaction_response_to_internal_transactions_params(%{id: id, result: calls}, id_to_params)
       when is_map(id_to_params) do
    %{block_number: block_number, hash_data: transaction_hash, transaction_index: transaction_index} =
      Map.fetch!(id_to_params, id)

    internal_transaction_params =
      calls
      |> Stream.with_index()
      |> Enum.map(fn {trace, index} ->
        Map.merge(trace, %{
          "blockNumber" => block_number,
          "index" => index,
          "transactionIndex" => transaction_index,
          "transactionHash" => transaction_hash
        })
      end)
      |> Calls.to_internal_transactions_params()

    {:ok, internal_transaction_params}
  end

  defp debug_trace_transaction_response_to_internal_transactions_params(%{id: id, error: error}, id_to_params)
       when is_map(id_to_params) do
    %{
      block_number: block_number,
      hash_data: "0x" <> transaction_hash_digits = transaction_hash,
      transaction_index: transaction_index
    } = Map.fetch!(id_to_params, id)

    not_found_message = "transaction " <> transaction_hash_digits <> " not found"

    normalized_error =
      case error do
        %{code: -32_000, message: ^not_found_message} ->
          %{message: :not_found}

        %{code: -32_000, message: "execution timeout"} ->
          %{message: :timeout}

        _ ->
          error
      end

    annotated_error =
      Map.put(normalized_error, :data, %{
        block_number: block_number,
        transaction_index: transaction_index,
        transaction_hash: transaction_hash
      })

    {:error, annotated_error}
  end

  defp reduce_internal_transactions_params(internal_transactions_params) when is_list(internal_transactions_params) do
    internal_transactions_params
    |> Enum.reduce({:ok, []}, &internal_transactions_params_reducer/2)
    |> finalize_internal_transactions_params()
  end

  defp internal_transactions_params_reducer(
         {:ok, internal_transactions_params},
         {:ok, acc_internal_transactions_params_list}
       ),
       do: {:ok, [internal_transactions_params, acc_internal_transactions_params_list]}

  defp internal_transactions_params_reducer({:ok, _}, {:error, _} = acc_error), do: acc_error
  defp internal_transactions_params_reducer({:error, reason}, {:ok, _}), do: {:error, [reason]}

  defp internal_transactions_params_reducer({:error, reason}, {:error, acc_reasons}) when is_list(acc_reasons),
    do: {:error, [reason | acc_reasons]}

  defp finalize_internal_transactions_params({:ok, acc_internal_transactions_params_list})
       when is_list(acc_internal_transactions_params_list) do
    internal_transactions_params =
      acc_internal_transactions_params_list
      |> Enum.reverse()
      |> List.flatten()

    {:ok, internal_transactions_params}
  end

  defp finalize_internal_transactions_params({:error, acc_reasons}) do
    {:error, Enum.reverse(acc_reasons)}
  end
end
