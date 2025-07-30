defmodule EthereumJSONRPC.Geth do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Geth](https://github.com/ethereum/go-ethereum/wiki/geth).
  """

  require Logger

  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.{FetchedBalance, FetchedCode, PendingTransaction, Utility.CommonHelper}
  alias EthereumJSONRPC.Geth.{Calls, PolygonTracer, Tracer}

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

    json_rpc_named_arguments_corrected_timeout = correct_timeouts(json_rpc_named_arguments)

    with {:ok, responses} <-
           id_to_params
           |> debug_trace_transaction_requests()
           |> json_rpc(json_rpc_named_arguments_corrected_timeout) do
      debug_trace_transaction_responses_to_internal_transactions_params(
        responses,
        id_to_params,
        json_rpc_named_arguments
      )
    end
  end

  def correct_timeouts(json_rpc_named_arguments) do
    debug_trace_timeout = Application.get_env(:ethereum_jsonrpc, __MODULE__)[:debug_trace_timeout]

    case CommonHelper.parse_duration(debug_trace_timeout) do
      {:error, :invalid_format} ->
        json_rpc_named_arguments

      parsed_timeout ->
        json_rpc_named_arguments
        |> Keyword.update(:transport_options, [http_options: []], &Keyword.put_new(&1, :http_options, []))
        |> put_in([:transport_options, :http_options, :timeout], parsed_timeout)
        |> put_in([:transport_options, :http_options, :recv_timeout], parsed_timeout)
    end
  end

  @doc """
  Fetches the first trace from the trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_first_trace(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    id_to_params = id_to_params(transactions_params)

    json_rpc_named_arguments_corrected_timeout = correct_timeouts(json_rpc_named_arguments)

    with {:ok, responses} <-
           id_to_params
           |> debug_trace_transaction_requests(true)
           |> json_rpc(json_rpc_named_arguments_corrected_timeout),
         {:ok, traces} <-
           debug_trace_transaction_responses_to_internal_transactions_params(
             responses,
             id_to_params,
             json_rpc_named_arguments_corrected_timeout
           ) do
      case {traces, transactions_params} do
        {[%{} = first_trace | _], [%{block_hash: block_hash} | _]} ->
          {:ok,
           [%{first_trace: first_trace, block_hash: block_hash, json_rpc_named_arguments: json_rpc_named_arguments}]}

        _ ->
          {:error, :not_found}
      end
    end
  end

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
         :ok <- check_errors_exist(blocks_responses, id_to_params) do
      transactions_params = to_transactions_params(blocks_responses, id_to_params)

      {transactions_id_to_params, transactions_responses} =
        Enum.reduce(transactions_params, {%{}, []}, fn {params, calls}, {id_to_params_acc, calls_acc} ->
          {Map.put(id_to_params_acc, params[:id], params), [calls | calls_acc]}
        end)

      debug_trace_transaction_responses_to_internal_transactions_params(
        transactions_responses,
        transactions_id_to_params,
        json_rpc_named_arguments
      )
    end
  end

  @doc """
  Fetches the raw traces from the Geth trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_transaction_raw_traces(%{hash: transaction_hash}, json_rpc_named_arguments) do
    request = debug_trace_transaction_request(%{id: 0, hash_data: to_string(transaction_hash)}, false)

    case json_rpc(request, json_rpc_named_arguments) do
      {:ok, traces} ->
        {:ok, traces}

      {:error, error} ->
        Logger.error(inspect(error))
        {:error, error}
    end
  end

  @spec check_errors_exist(list(), %{non_neg_integer() => any()}) :: :ok | {:error, list()}
  def check_errors_exist(blocks_responses, id_to_params) do
    blocks_responses
    |> EthereumJSONRPC.sanitize_responses(id_to_params)
    |> Enum.reduce([], fn
      %{result: result}, acc ->
        Enum.reduce(result, acc, fn
          %{"result" => _calls_result}, inner_acc -> inner_acc
          %{"error" => error}, inner_acc -> [error | inner_acc]
        end)

      %{error: error}, acc ->
        [error | acc]
    end)
    |> case do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  def to_transactions_params(blocks_responses, id_to_params) do
    blocks_responses
    |> Enum.reduce({[], 0}, fn %{id: id, result: transaction_result}, {blocks_acc, counter} ->
      {transactions_params, _, new_counter} =
        extract_transactions_params(Map.fetch!(id_to_params, id), transaction_result, counter)

      {transactions_params ++ blocks_acc, new_counter}
    end)
    |> elem(0)
  end

  defp extract_transactions_params(block_number, transaction_result, counter) do
    Enum.reduce(transaction_result, {[], 0, counter}, fn %{"txHash" => transaction_hash, "result" => calls_result},
                                                         {transaction_acc, inner_counter, counter} ->
      {
        [
          {%{block_number: block_number, hash_data: transaction_hash, transaction_index: inner_counter, id: counter},
           %{id: counter, result: calls_result}}
          | transaction_acc
        ],
        inner_counter + 1,
        counter + 1
      }
    end)
  end

  @doc """
  Fetches the pending transactions from the Geth node.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_pending_transactions(json_rpc_named_arguments) do
    PendingTransaction.fetch_pending_transactions_geth(json_rpc_named_arguments)
  end

  def debug_trace_transaction_requests(id_to_params, only_first_trace \\ false) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{hash_data: hash_data}} ->
      debug_trace_transaction_request(%{id: id, hash_data: hash_data}, only_first_trace)
    end)
  end

  defp debug_trace_block_by_number_requests(id_to_params) do
    Enum.map(id_to_params, &debug_trace_block_by_number_request/1)
  end

  @tracer_path "priv/js/ethereum_jsonrpc/geth/debug_traceTransaction/tracer.js"
  @external_resource @tracer_path
  @tracer File.read!(@tracer_path)

  defp debug_trace_transaction_request(%{id: id, hash_data: hash_data}, only_first_trace) do
    debug_trace_timeout = Application.get_env(:ethereum_jsonrpc, __MODULE__)[:debug_trace_timeout]

    request(%{
      id: id,
      method: "debug_traceTransaction",
      params: [hash_data, %{timeout: debug_trace_timeout} |> Map.merge(tracer_params(only_first_trace))]
    })
  end

  defp debug_trace_block_by_number_request({id, block_number}) do
    debug_trace_timeout = Application.get_env(:ethereum_jsonrpc, __MODULE__)[:debug_trace_timeout]

    request(%{
      id: id,
      method: "debug_traceBlockByNumber",
      params: [
        integer_to_quantity(block_number),
        %{timeout: debug_trace_timeout} |> Map.merge(tracer_params())
      ]
    })
  end

  defp tracer_params(only_first_trace \\ false) do
    cond do
      tracer_type() == "js" ->
        %{"tracer" => @tracer}

      tracer_type() in ~w(opcode polygon_edge) ->
        %{
          "enableMemory" => true,
          "disableStack" => false,
          "disableStorage" => true,
          "enableReturnData" => false
        }

      true ->
        if only_first_trace do
          %{"tracer" => "callTracer", "tracerConfig" => %{"onlyTopCall" => true}}
        else
          %{"tracer" => "callTracer"}
        end
    end
  end

  defp debug_trace_transaction_responses_to_internal_transactions_params(
         [%{result: %{"structLogs" => _}} | _] = responses,
         id_to_params,
         json_rpc_named_arguments
       )
       when is_map(id_to_params) do
    if tracer_type() not in ["opcode", "polygon_edge"] do
      Logger.warning(
        "structLogs found in debug_traceTransaction response, you should probably change your INDEXER_INTERNAL_TRANSACTIONS_TRACER_TYPE env value"
      )
    end

    with {:ok, receipts} <-
           id_to_params
           |> Enum.map(fn {id, %{hash_data: hash_data}} ->
             request(%{id: id, method: "eth_getTransactionReceipt", params: [hash_data]})
           end)
           |> json_rpc(json_rpc_named_arguments),
         {:ok, transactions} <-
           id_to_params
           |> Enum.map(fn {id, %{hash_data: hash_data}} ->
             request(%{id: id, method: "eth_getTransactionByHash", params: [hash_data]})
           end)
           |> json_rpc(json_rpc_named_arguments) do
      receipts_map = Enum.into(receipts, %{}, fn %{id: id, result: receipt} -> {id, receipt} end)
      transactions_map = Enum.into(transactions, %{}, fn %{id: id, result: transaction} -> {id, transaction} end)

      tracer =
        if Application.get_env(:ethereum_jsonrpc, __MODULE__)[:tracer] == "polygon_edge",
          do: PolygonTracer,
          else: Tracer

      responses
      |> Enum.map(fn
        %{result: %{"structLogs" => nil}} ->
          {:ok, []}

        %{id: id, result: %{"structLogs" => _} = result} ->
          debug_trace_transaction_response_to_internal_transactions_params(
            %{id: id, result: tracer.replay(result, Map.fetch!(receipts_map, id), Map.fetch!(transactions_map, id))},
            id_to_params
          )
      end)
      |> reduce_internal_transactions_params()
      |> fetch_missing_data(json_rpc_named_arguments)
    end
  end

  defp debug_trace_transaction_responses_to_internal_transactions_params(
         responses,
         id_to_params,
         _json_rpc_named_arguments
       )
       when is_list(responses) and is_map(id_to_params) do
    responses
    |> EthereumJSONRPC.sanitize_responses(id_to_params)
    |> Enum.map(&debug_trace_transaction_response_to_internal_transactions_params(&1, id_to_params))
    |> reduce_internal_transactions_params()
  end

  defp fetch_missing_data({:ok, transactions}, json_rpc_named_arguments) when is_list(transactions) do
    id_to_params = id_to_params(transactions)

    with {:ok, responses} <-
           id_to_params
           |> Enum.map(fn
             {id, %{created_contract_address_hash: address, block_number: block_number}} ->
               FetchedCode.request(%{id: id, block_quantity: integer_to_quantity(block_number), address: address})

             {id, %{type: "selfdestruct", from_address_hash: hash_data, block_number: block_number}} ->
               FetchedBalance.request(%{id: id, block_quantity: integer_to_quantity(block_number), hash_data: hash_data})

             _ ->
               nil
           end)
           |> Enum.reject(&is_nil/1)
           |> json_rpc(json_rpc_named_arguments) do
      results = Enum.into(responses, %{}, fn %{id: id, result: result} -> {id, result} end)

      transactions =
        id_to_params
        |> Enum.map(fn
          {id, %{created_contract_address_hash: _} = transaction} ->
            %{transaction | created_contract_code: Map.fetch!(results, id)}

          {id, %{type: "selfdestruct"} = transaction} ->
            %{transaction | value: Map.fetch!(results, id)}

          {_, transaction} ->
            transaction
        end)

      {:ok, transactions}
    end
  end

  defp fetch_missing_data(result, _json_rpc_named_arguments), do: result

  defp debug_trace_transaction_response_to_internal_transactions_params(%{id: id, result: calls}, id_to_params)
       when is_map(id_to_params) do
    %{block_number: block_number, hash_data: transaction_hash, transaction_index: transaction_index} =
      Map.fetch!(id_to_params, id)

    internal_transaction_params =
      calls
      |> prepare_calls()
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

  def prepare_calls(calls) do
    case Application.get_env(:ethereum_jsonrpc, __MODULE__)[:tracer] do
      "call_tracer" -> {calls, 0} |> parse_call_tracer_calls([], [], false) |> Enum.reverse()
      _ -> calls
    end
  end

  defp parse_call_tracer_calls(calls, acc, trace_address, inner? \\ true)
  defp parse_call_tracer_calls([], acc, _trace_address, _inner?), do: acc
  defp parse_call_tracer_calls({%{"type" => 0}, _}, acc, _trace_address, _inner?), do: acc

  defp parse_call_tracer_calls({%{"type" => type}, _}, [last | acc], _trace_address, _inner?)
       when type in ["STOP", "stop"] do
    [Map.put(last, "error", "execution stopped") | acc]
  end

  # credo:disable-for-next-line /Complexity/
  defp parse_call_tracer_calls({%{"type" => upcase_type, "from" => from} = call, index}, acc, trace_address, inner?) do
    case String.downcase(upcase_type) do
      type when type in ~w(call callcode delegatecall staticcall create create2 selfdestruct revert stop invalid) ->
        new_trace_address = [index | trace_address]

        formatted_call = %{
          "type" => if(type in ~w(call callcode delegatecall staticcall), do: "call", else: type),
          "callType" => type,
          "from" => from,
          "to" => Map.get(call, "to", "0x"),
          "createdContractAddressHash" => Map.get(call, "to", "0x"),
          "value" => Map.get(call, "value", "0x0"),
          "gas" => Map.get(call, "gas", "0x0"),
          "gasUsed" => Map.get(call, "gasUsed", "0x0"),
          "input" => Map.get(call, "input", "0x"),
          "output" => Map.get(call, "output", "0x"),
          "init" => Map.get(call, "input", "0x"),
          "createdContractCode" => Map.get(call, "output", "0x"),
          "traceAddress" => if(inner?, do: Enum.reverse(new_trace_address), else: []),
          "error" => call["error"]
        }

        parse_call_tracer_calls(
          Map.get(call, "calls", []),
          [formatted_call | acc],
          if(inner?, do: new_trace_address, else: [])
        )

      "" ->
        unless allow_empty_traces?(), do: log_unknown_type(call)
        acc

      _unknown_type ->
        log_unknown_type(call)
        acc
    end
  end

  defp parse_call_tracer_calls({%{} = call, _}, acc, _trace_address, _inner?) do
    unless allow_empty_traces?(), do: log_unknown_type(call)
    acc
  end

  defp parse_call_tracer_calls(calls, acc, trace_address, _inner) when is_list(calls) do
    calls
    |> Stream.with_index()
    |> Enum.reduce(acc, &parse_call_tracer_calls(&1, &2, trace_address))
  end

  defp log_unknown_type(call) do
    Logger.warning("Call from a callTracer with an unknown type: #{inspect(call)}")
  end

  @spec reduce_internal_transactions_params(list()) :: {:ok, list()} | {:error, list()}
  def reduce_internal_transactions_params(internal_transactions_params) when is_list(internal_transactions_params) do
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

  defp tracer_type do
    Application.get_env(:ethereum_jsonrpc, __MODULE__)[:tracer]
  end

  defp allow_empty_traces? do
    Application.get_env(:ethereum_jsonrpc, __MODULE__)[:allow_empty_traces?]
  end
end
