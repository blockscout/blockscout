defmodule Indexer.Transform.PolygonZkevm.Bridge do
  @moduledoc """
  Helper functions for transforming data for Polygon zkEVM Bridge operations.
  """

  require Logger

  import Indexer.Fetcher.PolygonZkevm.Bridge,
    only: [filter_bridge_events: 2, prepare_operations: 8]

  alias Indexer.Fetcher.PolygonZkevm.{BridgeL1, BridgeL2}
  alias Indexer.Helper

  @doc """
  Returns a list of operations given a list of blocks and logs.
  """
  @spec parse(list(), list()) :: list()
  def parse(blocks, logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :polygon_zkevm_bridge_l2_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, BridgeL2)[:start_block]),
           false <- Application.get_env(:explorer, :chain_type) != :polygon_zkevm,
           rpc_l1 = Application.get_all_env(:indexer)[BridgeL1][:rpc],
           {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(rpc_l1)},
           rollup_network_id_l1 = Application.get_all_env(:indexer)[BridgeL1][:rollup_network_id_l1],
           rollup_network_id_l2 = Application.get_all_env(:indexer)[BridgeL2][:rollup_network_id_l2],
           rollup_index_l1 = Application.get_all_env(:indexer)[BridgeL1][:rollup_index_l1],
           rollup_index_l2 = Application.get_all_env(:indexer)[BridgeL2][:rollup_index_l2],
           {:rollup_network_id_l1_is_valid, true} <-
             {:rollup_network_id_l1_is_valid, !is_nil(rollup_network_id_l1) and rollup_network_id_l1 >= 0},
           {:rollup_network_id_l2_is_valid, true} <-
             {:rollup_network_id_l2_is_valid, !is_nil(rollup_network_id_l2) and rollup_network_id_l2 > 0},
           {:rollup_index_l2_is_valid, true} <- {:rollup_index_l2_is_valid, !is_nil(rollup_index_l2)},
           bridge_contract = Application.get_env(:indexer, BridgeL2)[:bridge_contract],
           {:bridge_contract_address_is_valid, true} <-
             {:bridge_contract_address_is_valid, Helper.address_correct?(bridge_contract)} do
        bridge_contract = String.downcase(bridge_contract)

        block_numbers = Enum.map(blocks, fn block -> block.number end)
        start_block = Enum.min(block_numbers)
        end_block = Enum.max(block_numbers)

        Helper.log_blocks_chunk_handling(start_block, end_block, start_block, end_block, nil, :L2)

        json_rpc_named_arguments_l1 = Helper.json_rpc_named_arguments(rpc_l1)

        block_to_timestamp = Enum.reduce(blocks, %{}, fn block, acc -> Map.put(acc, block.number, block.timestamp) end)

        items =
          logs
          |> filter_bridge_events(bridge_contract)
          |> prepare_operations(
            rollup_network_id_l1,
            rollup_network_id_l2,
            rollup_index_l1,
            rollup_index_l2,
            nil,
            json_rpc_named_arguments_l1,
            block_to_timestamp
          )

        Helper.log_blocks_chunk_handling(
          start_block,
          end_block,
          start_block,
          end_block,
          "#{Enum.count(items)} L2 operation(s)",
          :L2
        )

        items
      else
        true ->
          []

        {:rpc_l1_undefined, true} ->
          Logger.error("L1 RPC URL is not defined. Cannot use #{__MODULE__} for parsing logs.")
          []

        {:rollup_network_id_l1_is_valid, false} ->
          Logger.error(
            "Invalid network ID for L1. Please, check INDEXER_POLYGON_ZKEVM_L1_BRIDGE_NETWORK_ID env variable."
          )

          []

        {:rollup_network_id_l2_is_valid, false} ->
          Logger.error(
            "Invalid network ID for L2. Please, check INDEXER_POLYGON_ZKEVM_L2_BRIDGE_NETWORK_ID env variable."
          )

          []

        {:rollup_index_l2_is_valid, false} ->
          Logger.error(
            "Rollup index is undefined for L2. Please, check INDEXER_POLYGON_ZKEVM_L2_BRIDGE_ROLLUP_INDEX env variable."
          )

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
