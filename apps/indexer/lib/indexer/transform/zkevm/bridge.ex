defmodule Indexer.Transform.Zkevm.Bridge do
  @moduledoc """
  Helper functions for transforming data for Polygon zkEVM Bridge operations.
  """

  require Logger

  import Indexer.Fetcher.Zkevm.Bridge,
    only: [filter_bridge_events: 2, json_rpc_named_arguments: 1, prepare_operations: 4]

  alias Indexer.Fetcher.Zkevm.{BridgeL1, BridgeL2}
  alias Indexer.Helper

  @doc """
  Returns a list of operations given a list of blocks and logs.
  """
  @spec parse(list(), list()) :: list()
  def parse(blocks, logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :zkevm_bridge_l2_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, BridgeL2)[:start_block]),
           false <- System.get_env("CHAIN_TYPE") != "polygon_zkevm",
           rpc_l1 = Application.get_all_env(:indexer)[BridgeL1][:rpc],
           {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(rpc_l1)},
           bridge_contract = Application.get_env(:indexer, BridgeL2)[:bridge_contract],
           {:bridge_contract_address_is_valid, true} <-
             {:bridge_contract_address_is_valid, Helper.address_correct?(bridge_contract)} do
        bridge_contract = String.downcase(bridge_contract)

        block_numbers = Enum.map(blocks, fn block -> block.number end)
        start_block = Enum.min(block_numbers)
        end_block = Enum.max(block_numbers)

        Helper.log_blocks_chunk_handling(start_block, end_block, start_block, end_block, nil, "L2")

        json_rpc_named_arguments_l1 = json_rpc_named_arguments(rpc_l1)

        block_to_timestamp = Enum.reduce(blocks, %{}, fn block, acc -> Map.put(acc, block.number, block.timestamp) end)

        items =
          logs
          |> filter_bridge_events(bridge_contract)
          |> prepare_operations(nil, json_rpc_named_arguments_l1, block_to_timestamp)

        Helper.log_blocks_chunk_handling(
          start_block,
          end_block,
          start_block,
          end_block,
          "#{Enum.count(items)} L2 operation(s)",
          "L2"
        )

        items
      else
        true ->
          []

        {:rpc_l1_undefined, true} ->
          Logger.error("L1 RPC URL is not defined. Cannot use #{__MODULE__} for parsing logs.")
          []

        {:bridge_contract_address_is_valid, false} ->
          Logger.error(
            "PolygonZkEVMBridge contract address is invalid or not defined. Cannot use #{__MODULE__} for parsing logs."
          )

          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
