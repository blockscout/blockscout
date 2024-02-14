defmodule Indexer.Fetcher.Arbitrum.Utils.Rpc do
  @moduledoc """
    TBD
  """

  import EthereumJSONRPC,
    only: [json_rpc: 2, quantity_to_integer: 1, timestamp_to_datetime: 1]

  import Indexer.Fetcher.Arbitrum.Utils.Helper, only: [list_to_chunks: 2]

  alias EthereumJSONRPC.Transport
  alias Indexer.Helper, as: IndexerHelper

  @rpc_resend_attempts 20

  @selector_outbox "ce11e6ab"
  @selector_sequencer_inbox "ee35f327"
  @selector_bridge "e78cea92"
  @rollup_contract_abi [
    %{
      "inputs" => [],
      "name" => "outbox",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "sequencerInbox",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "bridge",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @spec transaction_by_hash_request(%{:hash => any(), :id => binary() | non_neg_integer()}) :: Transport.request()
  def transaction_by_hash_request(%{id: id, hash: tx_hash}) do
    EthereumJSONRPC.request(%{id: id, method: "eth_getTransactionByHash", params: [tx_hash]})
  end

  @spec get_contracts_for_rollup(binary(), :bridge | :inbox_outbox, EthereumJSONRPC.json_rpc_named_arguments()) :: map()
  def get_contracts_for_rollup(rollup_address, contracts_set, json_rpc_named_arguments)

  def get_contracts_for_rollup(rollup_address, :bridge, json_rpc_named_arguments) do
    call_simple_getters_in_rollup_contract(rollup_address, [@selector_bridge], json_rpc_named_arguments)
  end

  def get_contracts_for_rollup(rollup_address, :inbox_outbox, json_rpc_named_arguments) do
    call_simple_getters_in_rollup_contract(
      rollup_address,
      [@selector_sequencer_inbox, @selector_outbox],
      json_rpc_named_arguments
    )
  end

  defp call_simple_getters_in_rollup_contract(rollup_address, method_ids, json_rpc_named_arguments) do
    method_ids
    |> Enum.map(fn method_id ->
      %{
        contract_address: rollup_address,
        method_id: method_id,
        args: []
      }
    end)
    |> IndexerHelper.read_contracts_with_retries(@rollup_contract_abi, json_rpc_named_arguments, @rpc_resend_attempts)
    |> Kernel.elem(0)
    |> Enum.zip(method_ids)
    |> Enum.reduce(%{}, fn {{:ok, [response]}, method_id}, retval ->
      Map.put(retval, atomized_key(method_id), response)
    end)
  end

  def make_chunked_request(requests_list, json_rpc_named_arguments, help_str) do
    error_message = &"Cannot call #{help_str}. Error: #{inspect(&1)}"

    {:ok, responses} =
      IndexerHelper.repeated_call(
        &json_rpc/2,
        [requests_list, json_rpc_named_arguments],
        error_message,
        @rpc_resend_attempts
      )

    Enum.map(responses, fn %{result: resp_body} -> resp_body end)
  end

  def execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size) do
    blocks_requests
    |> list_to_chunks(chunk_size)
    |> Enum.reduce(%{}, fn chunk, result ->
      chunk
      |> make_chunked_request(json_rpc_named_arguments, "eth_getBlockByNumber")
      |> Enum.reduce(result, fn resp, result_inner ->
        Map.put(result_inner, quantity_to_integer(resp["number"]), timestamp_to_datetime(resp["timestamp"]))
      end)
    end)
  end

  def execute_transactions_requests_and_get_from(txs_requests, json_rpc_named_arguments, chunk_size) do
    txs_requests
    |> list_to_chunks(chunk_size)
    |> Enum.reduce(%{}, fn chunk, result ->
      chunk
      |> make_chunked_request(json_rpc_named_arguments, "eth_getTransactionByHash")
      |> Enum.reduce(result, fn resp, result_inner ->
        Map.put(result_inner, resp["hash"], resp["from"])
      end)
    end)
  end

  def get_resend_attempts do
    @rpc_resend_attempts
  end

  defp atomized_key(@selector_outbox), do: :outbox
  defp atomized_key(@selector_sequencer_inbox), do: :sequencer_inbox
  defp atomized_key(@selector_bridge), do: :bridge
end
