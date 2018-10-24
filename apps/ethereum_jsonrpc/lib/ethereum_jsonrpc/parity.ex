defmodule EthereumJSONRPC.Parity do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Parity](https://wiki.parity.io/).
  """

  import EthereumJSONRPC, only: [id_to_params: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.Parity.Traces
  alias EthereumJSONRPC.{Transaction, Transactions}

  @behaviour EthereumJSONRPC.Variant

  @impl EthereumJSONRPC.Variant
  def fetch_beneficiaries(block_range, json_rpc_named_arguments) do
    Enum.reduce(
      Enum.with_index(block_range),
      {:ok, MapSet.new()},
      fn
        {block_number, index}, {:ok, beneficiaries} ->
          quantity = EthereumJSONRPC.integer_to_quantity(block_number)

          case trace_block(index, quantity, json_rpc_named_arguments) do
            {:ok, traces} when is_list(traces) ->
              new_beneficiaries = extract_beneficiaries(traces)
              {:ok, MapSet.union(new_beneficiaries, beneficiaries)}

            _ ->
              {:error, "Error fetching block reward contract beneficiaries"}
          end

        _, {:error, _} = error ->
          error
      end
    )
  end

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the Parity trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    id_to_params = id_to_params(transactions_params)

    with {:ok, responses} <-
           id_to_params
           |> trace_replay_transaction_requests()
           |> json_rpc(json_rpc_named_arguments) do
      trace_replay_transaction_responses_to_internal_transactions_params(responses, id_to_params)
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

  defp extract_beneficiaries(traces) when is_list(traces) do
    Enum.reduce(traces, MapSet.new(), fn
      %{"action" => %{"rewardType" => "block", "author" => author}, "blockNumber" => block_number}, beneficiaries ->
        beneficiary = %{
          block_number: block_number,
          address_hash: author
        }

        MapSet.put(beneficiaries, beneficiary)

      _, beneficiaries ->
        beneficiaries
    end)
  end

  defp trace_block(index, quantity, json_rpc_named_arguments) do
    %{id: index, method: "trace_block", params: [quantity]}
    |> request()
    |> json_rpc(json_rpc_named_arguments)
  end

  defp trace_replay_transaction_responses_to_internal_transactions_params(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    with {:ok, traces} <- trace_replay_transaction_responses_to_traces(responses, id_to_params) do
      params =
        traces
        |> Traces.to_elixir()
        |> Traces.elixir_to_params()

      {:ok, params}
    end
  end

  defp trace_replay_transaction_responses_to_traces(responses, id_to_params)
       when is_list(responses) and is_map(id_to_params) do
    responses
    |> Enum.map(&trace_replay_transaction_response_to_traces(&1, id_to_params))
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

  defp trace_replay_transaction_response_to_traces(%{id: id, result: %{"trace" => traces}}, id_to_params)
       when is_list(traces) and is_map(id_to_params) do
    %{block_number: block_number, hash_data: transaction_hash, transaction_index: transaction_index} =
      Map.fetch!(id_to_params, id)

    annotated_traces =
      traces
      |> Stream.with_index()
      |> Enum.map(fn {trace, index} ->
        Map.merge(trace, %{
          "blockNumber" => block_number,
          "index" => index,
          "transactionIndex" => transaction_index,
          "transactionHash" => transaction_hash
        })
      end)

    {:ok, annotated_traces}
  end

  defp trace_replay_transaction_response_to_traces(%{id: id, error: error}, id_to_params)
       when is_map(id_to_params) do
    %{block_number: block_number, hash_data: transaction_hash, transaction_index: transaction_index} =
      Map.fetch!(id_to_params, id)

    annotated_error =
      Map.put(error, :data, %{
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
