defmodule EthereumJSONRPC.Arbitrum do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Arbitrum L2]https://github.com/OffchainLabs/arbitrum).
  """

  import EthereumJSONRPC, only: [id_to_params: 1, integer_to_quantity: 1, json_rpc: 2, request: 1]

  alias EthereumJSONRPC.Geth

  @behaviour EthereumJSONRPC.Variant

  @doc """
  Block reward contract beneficiary fetching is not supported currently for Arbitrum L2.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_beneficiaries(_block_range, _json_rpc_named_arguments), do: :ignore

  @doc """
  Internal transaction fetching is not currently supported for Arbitrum L2.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_internal_transactions(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    id_to_params = id_to_params(transactions_params)

    json_rpc_named_arguments_corrected_timeout = Geth.correct_timeouts(json_rpc_named_arguments)

    with {:ok, responses} <-
           id_to_params
           |> Geth.debug_trace_transaction_requests()
           |> json_rpc(json_rpc_named_arguments_corrected_timeout) do
      Geth.debug_trace_transaction_responses_to_internal_transactions_params(
        responses,
        id_to_params,
        json_rpc_named_arguments
      )
    end
  end

  @doc """
  Internal transaction fetching is not currently supported for Arbitrum L2.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_block_internal_transactions(block_numbers, json_rpc_named_arguments) do
    id_to_params = id_to_params(block_numbers)

    with {:ok, blocks_responses} <-
           id_to_params
           |> Geth.debug_trace_block_by_number_requests()
           |> json_rpc(json_rpc_named_arguments),
         :ok <- Geth.check_errors_exist(blocks_responses, id_to_params) do
      transactions_params = Geth.to_transactions_params(blocks_responses, id_to_params)

      {transactions_id_to_params, transactions_responses} =
        Enum.reduce(transactions_params, {%{}, []}, fn {params, calls}, {id_to_params_acc, calls_acc} ->
          {Map.put(id_to_params_acc, params[:id], params), [calls | calls_acc]}
        end)

      Geth.debug_trace_transaction_responses_to_internal_transactions_params(
        transactions_responses,
        transactions_id_to_params,
        json_rpc_named_arguments
      )
    end
  end

  @doc """
  Pending transaction fetching is not supported currently for Arbitrum L2.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_pending_transactions(_json_rpc_named_arguments), do: :ignore

  @doc """
  Traces are not supported currently for Arbitrum L2.

  To signal to the caller that fetching is not supported, `:ignore` is returned.
  """
  @impl EthereumJSONRPC.Variant
  def fetch_first_trace(_transactions_params, _json_rpc_named_arguments), do: :ignore
end
