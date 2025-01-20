# credo:disable-for-this-file
defmodule EthereumJSONRPC.Besu do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Besu](https://besu.hyperledger.org/en/stable/Reference/API-Methods).
  """
  require Logger

  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.Besu.Traces
  alias EthereumJSONRPC.{FetchedBeneficiaries, PendingTransaction, TraceReplayBlockTransactions, Transaction}

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

  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(_transactions_params, _json_rpc_named_arguments), do: :ignore

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the Besu trace URL.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) when is_list(block_numbers) do
    TraceReplayBlockTransactions.fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments, Traces)
  end

  @impl EthereumJSONRPC.Variant
  def fetch_first_trace(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    TraceReplayBlockTransactions.fetch_first_trace(transactions_params, json_rpc_named_arguments, Traces)
  end

  @doc """
  Fetches the pending transactions from the Besu node.

  *NOTE*: The pending transactions are local to the node that is contacted and may not be consistent across nodes based
  on the transactions that each node has seen and how each node prioritizes collating transactions into the next block.
  """
  @impl EthereumJSONRPC.Variant
  @spec fetch_pending_transactions(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {:ok, [Transaction.params()]} | {:error, reason :: term}
  def fetch_pending_transactions(json_rpc_named_arguments) do
    PendingTransaction.fetch_pending_transactions_besu(json_rpc_named_arguments)
  end

  @impl EthereumJSONRPC.Variant
  def fetch_transaction_raw_traces(%{hash: transaction_hash}, json_rpc_named_arguments) do
    request = trace_transaction_request(%{id: 0, hash_data: to_string(transaction_hash)})

    case json_rpc(request, json_rpc_named_arguments) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        Logger.error(inspect(error))
        {:error, error}
    end
  end

  defp block_numbers_to_params_list(block_numbers) when is_list(block_numbers) do
    Enum.map(block_numbers, &%{block_quantity: integer_to_quantity(&1)})
  end

  defp trace_transaction_request(%{id: id, hash_data: hash_data}) do
    request(%{id: id, method: "trace_transaction", params: [hash_data]})
  end
end
