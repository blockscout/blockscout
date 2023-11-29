defmodule Indexer.Transform.Shibarium.Bridge do
  @moduledoc """
  Helper functions for transforming data for Shibarium Bridge operations.
  """

  require Logger

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  import Indexer.Fetcher.Shibarium.L2,
    only: [
      token_deposited_event_signature: 0,
      transfer_event_signature: 0,
      transfer_single_event_signature: 0,
      transfer_batch_event_signature: 0,
      withdraw_event_signature: 0,
      withdraw_method_signature: 0
    ]

  alias Indexer.Fetcher.Shibarium.L2
  alias Indexer.Helper

  @empty_hash "0x0000000000000000000000000000000000000000000000000000000000000000"

  @doc """
  Returns a list of operations given a list of blocks and their transactions.
  """
  @spec parse(list(), list(), list()) :: list()
  def parse(blocks, transactions_with_receipts, logs) do
    prev_metadata = Logger.metadata()
    Logger.metadata(fetcher: :shibarium_bridge_l2_realtime)

    items =
      with false <- is_nil(Application.get_env(:indexer, Indexer.Fetcher.Shibarium.L2)[:start_block]),
           false <- System.get_env("CHAIN_TYPE") != "shibarium",
           child_chain = Application.get_env(:indexer, Indexer.Fetcher.Shibarium.L2)[:child_chain],
           weth = Application.get_env(:indexer, Indexer.Fetcher.Shibarium.L2)[:weth],
           bone_withdraw = Application.get_env(:indexer, Indexer.Fetcher.Shibarium.L2)[:bone_withdraw],
           true <- Helper.is_address_correct?(child_chain),
           true <- Helper.is_address_correct?(weth),
           true <- Helper.is_address_correct?(bone_withdraw) do
        child_chain = String.downcase(child_chain)
        weth = String.downcase(weth)
        bone_withdraw = String.downcase(bone_withdraw)

        block_numbers = Enum.map(blocks, fn block -> block.number end)
        start_block = Enum.min(block_numbers)
        end_block = Enum.max(block_numbers)

        L2.log_blocks_chunk_handling(start_block, end_block, start_block, end_block, nil, "L2")

        deposit_transaction_hashes =
          transactions_with_receipts
          |> Enum.filter(fn tx -> tx.from_address_hash == burn_address_hash_string() end)
          |> Enum.map(fn tx -> tx.hash end)

        tokens_deposit_result =
          logs
          |> Enum.filter(&Enum.member?(deposit_transaction_hashes, &1.transaction_hash))
          |> Enum.filter(fn event ->
            address = String.downcase(event.address_hash)

            (event.first_topic == token_deposited_event_signature() and address == child_chain) or
              (event.first_topic == transfer_event_signature() and event.second_topic == @empty_hash and
                 event.third_topic != @empty_hash) or
              (Enum.member?([transfer_single_event_signature(), transfer_batch_event_signature()], event.first_topic) and
                 event.third_topic == @empty_hash and event.fourth_topic != @empty_hash)
          end)

        withdrawal_transaction_hashes =
          transactions_with_receipts
          |> Enum.filter(fn tx ->
            # filter by `withdraw(uint256 amount)` signature
            String.downcase(String.slice(tx.input, 0..9)) == withdraw_method_signature()
          end)
          |> Enum.map(fn tx -> tx.hash end)

        tokens_withdraw_result =
          logs
          |> Enum.filter(&Enum.member?(withdrawal_transaction_hashes, &1.transaction_hash))
          |> Enum.filter(fn event ->
            address = String.downcase(event.address_hash)

            (event.first_topic == withdraw_event_signature() and address == bone_withdraw) or
              (event.first_topic == transfer_event_signature() and event.second_topic != @empty_hash and
                 event.third_topic == @empty_hash) or
              (Enum.member?([transfer_single_event_signature(), transfer_batch_event_signature()], event.first_topic) and
                 event.third_topic != @empty_hash and event.fourth_topic == @empty_hash)
          end)

        events = tokens_deposit_result ++ tokens_withdraw_result
        timestamps = Enum.reduce(blocks, %{}, fn block, acc -> Map.put(acc, block.number, block.timestamp) end)

        operations = L2.prepare_operations({events, timestamps}, weth)
        items = L2.prepare_insert_items(operations)

        L2.log_blocks_chunk_handling(
          start_block,
          end_block,
          start_block,
          end_block,
          "#{Enum.count(operations)} L2 operation(s)",
          "L2"
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
