defmodule EthereumJSONRPC.Parity do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Parity](https://wiki.parity.io/).
  """

  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.Parity.{FetchedBeneficiaries, Traces}
  alias EthereumJSONRPC.{Transaction, Transactions}

  alias Explorer.Chain
  alias Explorer.Chain.{Data, Wei}
  alias Explorer.Chain.InternalTransaction.{CallType, Type}

  @behaviour EthereumJSONRPC.Variant

  @impl EthereumJSONRPC.Variant
  def fetch_beneficiaries(block_numbers, json_rpc_named_arguments)
      when is_list(block_numbers) and is_list(json_rpc_named_arguments) do
    id_to_params =
      block_numbers
      |> block_numbers_to_params_list()
      |> id_to_params()

    with {:ok, responses} <-
           id_to_params
           |> FetchedBeneficiaries.requests()
           |> json_rpc(json_rpc_named_arguments) do
      {:ok, FetchedBeneficiaries.from_responses(responses, id_to_params)}
    end
  end

  @doc """
  Internal transaction fetching for individual transactions is no longer supported for Parity.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(_transactions_params, _json_rpc_named_arguments), do: :ignore

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the Parity trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) when is_list(block_numbers) do
    id_to_params = id_to_params(block_numbers)

    with {:ok, responses} <-
           id_to_params
           |> trace_replay_block_transactions_requests()
           |> json_rpc(json_rpc_named_arguments) do
      trace_replay_block_transactions_responses_to_internal_transactions_params(responses, id_to_params)
    end
  end

  @doc """
  Fetches the pending transactions from the Parity node.

  *NOTE*: The pending transactions are local to the node that is contacted and may not be consistent across nodes based
  on the transactions that each node has seen and how each node prioritizes collating transactions into the next block.
  """
  @impl EthereumJSONRPC.Variant
  @spec fetch_pending_transactions(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {:ok, [Transaction.params()]} | {:error, reason :: term}
  def fetch_pending_transactions(json_rpc_named_arguments) do
    with {:ok, transactions} <-
           %{id: 1, method: "parity_pendingTransactions", params: []}
           |> request()
           |> json_rpc(json_rpc_named_arguments) do
      transactions_params =
        transactions
        |> Transactions.to_elixir()
        |> Transactions.elixir_to_params()

      {:ok, transactions_params}
    end
  end

  defp block_numbers_to_params_list(block_numbers) when is_list(block_numbers) do
    Enum.map(block_numbers, &%{block_quantity: integer_to_quantity(&1)})
  end

  defp trace_replay_block_transactions_responses_to_internal_transactions_params(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    with {:ok, traces} <- trace_replay_block_transactions_responses_to_traces(responses, id_to_params) do
      params =
        traces
        |> Traces.to_elixir()
        |> Traces.elixir_to_params()

      {:ok, params}
    end
  end

  defp trace_replay_block_transactions_responses_to_traces(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    responses
    |> Enum.map(&trace_replay_block_transactions_response_to_traces(&1, id_to_params))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, traces}, {:ok, acc_traces_list} ->
          {:ok, [traces | acc_traces_list]}

        {:ok, _}, {:error, _} = acc_error ->
          acc_error

        {:error, reason}, {:ok, _} ->
          {:error, [reason]}

        {:error, reason}, {:error, acc_reason} ->
          {:error, [reason | acc_reason]}
      end
    )
    |> case do
      {:ok, traces_list} ->
        traces =
          traces_list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, traces}

      {:error, reverse_reasons} ->
        reasons = Enum.reverse(reverse_reasons)
        {:error, reasons}
    end
  end

  defp trace_replay_block_transactions_response_to_traces(%{id: id, result: results}, id_to_params)
       when is_list(results) and is_map(id_to_params) do
    block_number = Map.fetch!(id_to_params, id)

    annotated_traces =
      results
      |> Stream.with_index()
      |> Enum.flat_map(fn {%{"trace" => traces, "transactionHash" => transaction_hash}, transaction_index} ->
        traces
        |> Stream.with_index()
        |> Enum.map(fn {trace, index} ->
          Map.merge(trace, %{
            "blockNumber" => block_number,
            "transactionHash" => transaction_hash,
            "transactionIndex" => transaction_index,
            "index" => index
          })
        end)
      end)

    {:ok, annotated_traces}
  end

  defp trace_replay_block_transactions_response_to_traces(%{id: id, error: error}, id_to_params)
       when is_map(id_to_params) do
    block_number = Map.fetch!(id_to_params, id)

    annotated_error =
      Map.put(error, :data, %{
        "blockNumber" => block_number
      })

    {:error, annotated_error}
  end

  defp trace_replay_block_transactions_requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, block_number} ->
      trace_replay_block_transactions_request(%{id: id, block_number: block_number})
    end)
  end

  defp trace_replay_block_transactions_request(%{id: id, block_number: block_number}) do
    request(%{id: id, method: "trace_replayBlockTransactions", params: [integer_to_quantity(block_number), ["trace"]]})
  end

  @doc """
  Fetches the first trace from the Parity trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_first_trace(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    id_to_params = id_to_params(transactions_params)

    with {:ok, responses} <-
           id_to_params
           |> trace_replay_transaction_requests()
           |> json_rpc(json_rpc_named_arguments) do
      {:ok, [first_trace]} = trace_replay_transaction_responses_to_first_trace_params(responses, id_to_params)

      %{block_hash: block_hash} =
        transactions_params
        |> Enum.at(0)

      {:ok, to_address_hash} =
        if Map.has_key?(first_trace, :to_address_hash) do
          Chain.string_to_address_hash(first_trace.to_address_hash)
        else
          {:ok, nil}
        end

      {:ok, from_address_hash} = Chain.string_to_address_hash(first_trace.from_address_hash)

      {:ok, created_contract_address_hash} =
        if Map.has_key?(first_trace, :created_contract_address_hash) do
          Chain.string_to_address_hash(first_trace.created_contract_address_hash)
        else
          {:ok, nil}
        end

      {:ok, transaction_hash} = Chain.string_to_transaction_hash(first_trace.transaction_hash)

      {:ok, call_type} =
        if Map.has_key?(first_trace, :call_type) do
          CallType.load(first_trace.call_type)
        else
          {:ok, nil}
        end

      {:ok, type} = Type.load(first_trace.type)

      {:ok, input} =
        if Map.has_key?(first_trace, :input) do
          Data.cast(first_trace.input)
        else
          {:ok, nil}
        end

      {:ok, output} =
        if Map.has_key?(first_trace, :output) do
          Data.cast(first_trace.output)
        else
          {:ok, nil}
        end

      {:ok, created_contract_code} =
        if Map.has_key?(first_trace, :created_contract_code) do
          Data.cast(first_trace.created_contract_code)
        else
          {:ok, nil}
        end

      {:ok, init} =
        if Map.has_key?(first_trace, :init) do
          Data.cast(first_trace.init)
        else
          {:ok, nil}
        end

      block_index =
        get_block_index(%{
          transaction_index: first_trace.transaction_index,
          transaction_hash: first_trace.transaction_hash,
          block_number: first_trace.block_number,
          json_rpc_named_arguments: json_rpc_named_arguments
        })

      value = %Wei{value: Decimal.new(first_trace.value)}

      first_trace_formatted =
        first_trace
        |> Map.merge(%{
          block_index: block_index,
          block_hash: block_hash,
          call_type: call_type,
          to_address_hash: to_address_hash,
          created_contract_address_hash: created_contract_address_hash,
          from_address_hash: from_address_hash,
          input: input,
          output: output,
          created_contract_code: created_contract_code,
          init: init,
          transaction_hash: transaction_hash,
          type: type,
          value: value
        })

      {:ok, [first_trace_formatted]}
    end
  end

  defp get_block_index(%{
         transaction_index: transaction_index,
         transaction_hash: transaction_hash,
         block_number: block_number,
         json_rpc_named_arguments: json_rpc_named_arguments
       }) do
    if transaction_index == 0 do
      0
    else
      {:ok, traces} = fetch_block_internal_transactions([block_number], json_rpc_named_arguments)

      sorted_traces =
        traces
        |> Enum.sort_by(&{&1.transaction_index, &1.index})
        |> Enum.with_index()

      {_, block_index} =
        sorted_traces
        |> Enum.find(fn {trace, _} ->
          trace.transaction_index == transaction_index &&
            trace.transaction_hash == transaction_hash
        end)

      block_index
    end
  end

  defp trace_replay_transaction_responses_to_first_trace_params(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    with {:ok, traces} <- trace_replay_transaction_responses_to_first_trace(responses, id_to_params) do
      params =
        traces
        |> Traces.to_elixir()
        |> Traces.elixir_to_params()

      {:ok, params}
    end
  end

  defp trace_replay_transaction_responses_to_first_trace(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    responses
    |> Enum.map(&trace_replay_transaction_response_to_first_trace(&1, id_to_params))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, traces}, {:ok, acc_traces_list} ->
          {:ok, [traces | acc_traces_list]}

        {:ok, _}, {:error, _} = acc_error ->
          acc_error

        {:error, reason}, {:ok, _} ->
          {:error, [reason]}

        {:error, reason}, {:error, acc_reason} ->
          {:error, [reason | acc_reason]}
      end
    )
    |> case do
      {:ok, traces_list} ->
        traces =
          traces_list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, traces}

      {:error, reverse_reasons} ->
        reasons = Enum.reverse(reverse_reasons)
        {:error, reasons}
    end
  end

  defp trace_replay_transaction_response_to_first_trace(%{id: id, result: %{"trace" => traces}}, id_to_params)
       when is_list(traces) and is_map(id_to_params) do
    %{
      block_hash: block_hash,
      block_number: block_number,
      hash_data: transaction_hash,
      transaction_index: transaction_index
    } = Map.fetch!(id_to_params, id)

    first_trace =
      traces
      |> Stream.with_index()
      |> Enum.map(fn {trace, index} ->
        Map.merge(trace, %{
          "blockHash" => block_hash,
          "blockNumber" => block_number,
          "index" => index,
          "transactionIndex" => transaction_index,
          "transactionHash" => transaction_hash
        })
      end)
      |> Enum.filter(fn trace ->
        Map.get(trace, "index") == 0
      end)

    {:ok, first_trace}
  end

  defp trace_replay_transaction_response_to_first_trace(%{id: id, error: error}, id_to_params)
       when is_map(id_to_params) do
    %{
      block_hash: block_hash,
      block_number: block_number,
      hash_data: transaction_hash,
      transaction_index: transaction_index
    } = Map.fetch!(id_to_params, id)

    annotated_error =
      Map.put(error, :data, %{
        "blockHash" => block_hash,
        "blockNumber" => block_number,
        "transactionIndex" => transaction_index,
        "transactionHash" => transaction_hash
      })

    {:error, annotated_error}
  end

  defp trace_replay_transaction_requests(id_to_params) when is_map(id_to_params) do
    Enum.map(id_to_params, fn {id, %{hash_data: hash_data}} ->
      trace_replay_transaction_request(%{id: id, hash_data: hash_data})
    end)
  end

  defp trace_replay_transaction_request(%{id: id, hash_data: hash_data}) do
    request(%{id: id, method: "trace_replayTransaction", params: [hash_data, ["trace"]]})
  end
end
