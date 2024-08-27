defmodule Indexer.Transform.Scroll.Bridge do
  @moduledoc """
  Helper functions for transforming data for Scroll bridge operations.
  """

  require Logger

  import Indexer.Fetcher.Scroll.Bridge,
    only: [filter_messenger_events: 2, prepare_operations: 4]

  alias Indexer.Fetcher.Scroll.BridgeL2
  alias Indexer.Helper

  @doc """
  Returns a list of operations given a list of blocks and logs.
  """
  @spec parse(list(), list()) :: list()
  def parse(blocks, logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :scroll_bridge_l2_realtime)

    items =
      with false <- Application.get_env(:explorer, :chain_type) != :scroll,
           messenger_contract = Application.get_env(:indexer, BridgeL2)[:messenger_contract],
           {:messenger_contract_address_is_valid, true} <-
             {:messenger_contract_address_is_valid, Helper.address_correct?(messenger_contract)} do
        messenger_contract = String.downcase(messenger_contract)

        block_numbers = Enum.map(blocks, fn block -> block.number end)
        start_block = Enum.min(block_numbers)
        end_block = Enum.max(block_numbers)

        Helper.log_blocks_chunk_handling(start_block, end_block, start_block, end_block, nil, :L2)

        block_to_timestamp = Enum.reduce(blocks, %{}, fn block, acc -> Map.put(acc, block.number, block.timestamp) end)

        items =
          logs
          |> filter_messenger_events(messenger_contract)
          |> prepare_operations(false, nil, block_to_timestamp)

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

        {:messenger_contract_address_is_valid, false} ->
          Logger.error(
            "L2ScrollMessenger contract address is invalid or not defined. Cannot use #{__MODULE__} for parsing logs."
          )

          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
