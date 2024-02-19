defmodule EthereumJSONRPC.Filecoin do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by Filecoin.
  """

  require Logger

  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.Geth
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
  def fetch_internal_transactions(_transactions_params, _json_rpc_named_arguments), do: :ignore

  @doc """
  Fetches the first trace from the trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_first_trace(_transactions_params, _json_rpc_named_arguments), do: :ignore

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the Geth trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) do
    id_to_params = id_to_params(block_numbers)

    with {:ok, blocks_responses} <-
           id_to_params
           |> debug_trace_block_by_number_requests()
           |> json_rpc(json_rpc_named_arguments),
         :ok <- Geth.check_errors_exist(blocks_responses, id_to_params) do
      transactions_params = to_transactions_params(blocks_responses, id_to_params)

      {transactions_id_to_params, transactions_responses} =
        Enum.reduce(transactions_params, {%{}, []}, fn {params, calls}, {id_to_params_acc, calls_acc} ->
          {Map.put(id_to_params_acc, params[:id], params), [calls | calls_acc]}
        end)

      debug_trace_transaction_responses_to_internal_transactions_params(
        transactions_responses,
        transactions_id_to_params
      )
    end
  end

  defp to_transactions_params(blocks_responses, id_to_params) do
    Enum.reduce(blocks_responses, [], fn %{id: id, result: tx_result}, blocks_acc ->
      extract_transactions_params(Map.fetch!(id_to_params, id), tx_result) ++ blocks_acc
    end)
  end

  defp extract_transactions_params(block_number, tx_result) do
    tx_result
    |> Enum.reduce({[], 0}, fn %{"transactionHash" => tx_hash, "transactionPosition" => transaction_index} =
                                 calls_result,
                               {tx_acc, counter} ->
      {
        [
          {%{block_number: block_number, hash_data: tx_hash, transaction_index: transaction_index, id: counter},
           %{id: counter, result: calls_result}}
          | tx_acc
        ],
        counter + 1
      }
    end)
    |> elem(0)
  end

  @doc """
  Fetches the pending transactions from the Geth node.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_pending_transactions(_json_rpc_named_arguments), do: :ignore

  defp debug_trace_block_by_number_requests(id_to_params) do
    Enum.map(id_to_params, &debug_trace_block_by_number_request/1)
  end

  defp debug_trace_block_by_number_request({id, block_number}) do
    request(%{
      id: id,
      method: "trace_block",
      params: [integer_to_quantity(block_number)]
    })
  end

  defp debug_trace_transaction_responses_to_internal_transactions_params(
         responses,
         id_to_params
       )
       when is_list(responses) and is_map(id_to_params) do
    responses
    |> EthereumJSONRPC.sanitize_responses(id_to_params)
    |> Enum.map(&debug_trace_transaction_response_to_internal_transactions_params(&1, id_to_params))
    |> Geth.reduce_internal_transactions_params()
  end

  defp debug_trace_transaction_response_to_internal_transactions_params(%{id: id, result: calls}, id_to_params)
       when is_map(id_to_params) do
    %{block_number: block_number, hash_data: transaction_hash, transaction_index: transaction_index, id: id} =
      Map.fetch!(id_to_params, id)

    internal_transaction_params =
      calls
      |> parse_trace_block_calls()
      |> (&if(is_list(&1), do: &1, else: [&1])).()
      |> Enum.map(fn trace ->
        Map.merge(trace, %{
          "blockNumber" => block_number,
          "index" => id,
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

  defp parse_trace_block_calls(calls)
  defp parse_trace_block_calls(%{"type" => 0} = res), do: res

  defp parse_trace_block_calls(%{"Type" => type} = call) do
    sanitized_call =
      call
      |> Map.put("type", type)
      |> Map.drop(["Type"])

    parse_trace_block_calls(sanitized_call)
  end

  defp parse_trace_block_calls(
         %{"type" => upcase_type, "action" => %{"from" => from} = action, "result" => result} = call
       ) do
    type = String.downcase(upcase_type)

    to = Map.get(action, "to", "0x")
    input = Map.get(action, "input", "0x")

    %{
      "type" => if(type in ~w(call callcode delegatecall staticcall), do: "call", else: type),
      "callType" => type,
      "from" => from,
      "to" => to,
      "createdContractAddressHash" => to,
      "value" => Map.get(action, "value", "0x0"),
      "gas" => Map.get(action, "gas", "0x0"),
      "gasUsed" => Map.get(result, "gasUsed", "0x0"),
      "input" => input,
      "init" => input,
      "createdContractCode" => Map.get(result, "output", "0x"),
      "traceAddress" => Map.get(call, "traceAddress", []),
      # : check, that error is returned in the root of the call
      "error" => call["error"]
    }
    |> case do
      %{"error" => nil} = ok_call ->
        ok_call
        |> Map.delete("error")
        # to handle staticcall, all other cases handled by EthereumJSONRPC.Geth.Call.elixir_to_internal_transaction_params/1
        |> Map.put("output", Map.get(call, "output", "0x"))

      error_call ->
        error_call
    end
  end
end
