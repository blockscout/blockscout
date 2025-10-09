defmodule Indexer.Transform.Shibarium.Bridge do
  @moduledoc """
  Helper functions for transforming data for Shibarium Bridge operations.
  """

  require Logger

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  import Indexer.Fetcher.Shibarium.Helper, only: [prepare_insert_items: 2]

  import Indexer.Fetcher.Shibarium.L2, only: [withdraw_method_signature: 0]

  alias Indexer.Fetcher.Shibarium.L2
  alias Indexer.Helper

  @doc """
  Returns a list of operations given a list of blocks and their transactions.
  """
  @spec parse(list(), list(), list()) :: list()
  def parse(blocks, transactions_with_receipts, logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :shibarium_bridge_l2_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, Indexer.Fetcher.Shibarium.L2)[:start_block]),
           false <- Application.get_env(:explorer, :chain_type) != :shibarium,
           child_chain = Application.get_env(:indexer, Indexer.Fetcher.Shibarium.L2)[:child_chain],
           weth = Application.get_env(:indexer, Indexer.Fetcher.Shibarium.L2)[:weth],
           bone_withdraw = Application.get_env(:indexer, Indexer.Fetcher.Shibarium.L2)[:bone_withdraw],
           true <- Helper.address_correct?(child_chain),
           true <- Helper.address_correct?(weth),
           true <- Helper.address_correct?(bone_withdraw) do
        child_chain = String.downcase(child_chain)
        weth = String.downcase(weth)
        bone_withdraw = String.downcase(bone_withdraw)

        block_numbers = Enum.map(blocks, fn block -> block.number end)
        start_block = Enum.min(block_numbers)
        end_block = Enum.max(block_numbers)

        Helper.log_blocks_chunk_handling(start_block, end_block, start_block, end_block, nil, :L2)

        deposit_transaction_hashes =
          transactions_with_receipts
          |> Enum.filter(fn transaction -> transaction.from_address_hash == burn_address_hash_string() end)
          |> Enum.map(fn transaction -> transaction.hash end)

        deposit_events =
          logs
          |> Enum.filter(&Enum.member?(deposit_transaction_hashes, &1.transaction_hash))
          |> L2.filter_deposit_events(child_chain)

        withdrawal_transaction_hashes =
          transactions_with_receipts
          |> Enum.filter(fn transaction ->
            # filter by `withdraw(uint256 amount)` signature
            String.downcase(String.slice(transaction.input, 0..9)) == withdraw_method_signature()
          end)
          |> Enum.map(fn transaction -> transaction.hash end)

        withdrawal_events =
          logs
          |> Enum.filter(&Enum.member?(withdrawal_transaction_hashes, &1.transaction_hash))
          |> L2.filter_withdrawal_events(bone_withdraw)

        events = deposit_events ++ withdrawal_events
        timestamps = Enum.reduce(blocks, %{}, fn block, acc -> Map.put(acc, block.number, block.timestamp) end)

        operations = L2.prepare_operations({events, timestamps}, weth)
        items = prepare_insert_items(operations, L2)

        Helper.log_blocks_chunk_handling(
          start_block,
          end_block,
          start_block,
          end_block,
          "#{Enum.count(operations)} L2 operation(s)",
          :L2
        )

        items
      else
        true ->
          []

        false ->
          Logger.error(
            "ChildChain or WETH or BoneWithdraw contract address is incorrect. Cannot use #{__MODULE__} for parsing logs."
          )

          []
      end

    Logger.reset_metadata(prev_metadata)

    items
  end
end
