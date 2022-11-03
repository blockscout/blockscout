# credo:disable-for-this-file
defmodule EthereumJSONRPC.Nethermind do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by Nethermind.
  """
  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2]

  alias EthereumJSONRPC.Nethermind.Traces
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
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the Nethermind trace URL.
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
  Fetches the pending transactions from the Nethermind node.

  *NOTE*: The pending transactions are local to the node that is contacted and may not be consistent across nodes based
  on the transactions that each node has seen and how each node prioritizes collating transactions into the next block.
  """
  @impl EthereumJSONRPC.Variant
  @spec fetch_pending_transactions(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {:ok, [Transaction.params()]} | {:error, reason :: term}
  def fetch_pending_transactions(json_rpc_named_arguments) do
    if Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.PendingTransaction)[:type] == "geth" do
      PendingTransaction.fetch_pending_transactions_geth(json_rpc_named_arguments)
    else
      PendingTransaction.fetch_pending_transactions_parity(json_rpc_named_arguments)
    end
  end

  defp block_numbers_to_params_list(block_numbers) when is_list(block_numbers) do
    Enum.map(block_numbers, &%{block_quantity: integer_to_quantity(&1)})
  end
end
