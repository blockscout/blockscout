defmodule Indexer.Fetcher.Arbitrum.Workers.Backfill do
  @moduledoc """
  Worker for backfilling missing Arbitrum-specific fields in blocks and transactions.
  """
  import Ecto.Query
  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1, log_info: 1]

  alias EthereumJSONRPC
  alias Explorer.Chain
  alias Explorer.Repo

  alias Indexer.Fetcher.Arbitrum.Utils.Db, as: ArbitrumDbUtils

  alias Ecto.Multi

  require Logger

  def discover_blocks(end_block, state) do
    start_block = max(state.config.rollup_rpc.first_block, end_block - state.config.backfill_blocks_depth + 1)

    if ArbitrumDbUtils.indexed_blocks?(start_block, end_block) do
      case do_discover_blocks(start_block, end_block, state) do
        :ok -> {:ok, start_block}
        :error -> {:error, :discover_blocks_error}
      end
    else
      log_warning(
        "Not able to discover rollup blocks to backfill, some blocks in #{start_block}..#{end_block} not indexed"
      )

      {:error, :not_indexed_blocks}
    end
  end

  defp do_discover_blocks(start_block, end_block, %{config: %{rollup_rpc: %{chunk_size: chunk_size, json_rpc_named_arguments: json_rpc_named_arguments}}}) do
    log_info("Block range for blocks information backfill: #{start_block}..#{end_block}")

    with {:block_numbers, block_numbers} <- {:block_numbers, ArbitrumDbUtils.blocks_with_missing_fields(start_block, end_block)},
         {:ok, blocks} <- fetch_blocks(block_numbers, json_rpc_named_arguments, chunk_size),
         {:ok, receipts} <- fetch_receipts(block_numbers, json_rpc_named_arguments, chunk_size) do

      multi =
        Multi.new()
        |> update_blocks(blocks)
        |> update_transactions(receipts)

      case Repo.transaction(multi) do
        {:ok, _} -> :ok
        {:error, _, _, _} -> :error
      end
    else
      {:error, _} -> :error
    end
  end

  defp fetch_blocks(block_numbers, json_rpc_named_arguments, chunk_size) do
    block_numbers
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
      case EthereumJSONRPC.fetch_blocks_by_numbers(chunk, json_rpc_named_arguments, false) do
        {:ok, %EthereumJSONRPC.Blocks{blocks_params: blocks}} -> {:cont, {:ok, acc ++ blocks}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp fetch_receipts(block_numbers, json_rpc_named_arguments, chunk_size) do
    block_numbers
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
      case EthereumJSONRPC.Receipts.fetch_by_block_numbers(chunk, json_rpc_named_arguments) do
        {:ok, %{receipts: receipts}} -> {:cont, {:ok, acc ++ receipts}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp update_blocks(multi, blocks) do
    blocks
    |> Enum.reduce(multi, fn block, multi_acc ->
      Multi.update_all(
        multi_acc,
        {:block, block.hash},
        from(b in Chain.Block, where: b.hash == ^block.hash),
        [set: [
          send_count: block.send_count,
          send_root: block.send_root,
          l1_block_number: block.l1_block_number
        ]]
      )
    end)
  end

  defp update_transactions(multi, receipts) do
    receipts
    |> Enum.reduce(multi, fn receipt, multi_acc ->
      Multi.update_all(
        multi_acc,
        {:transaction, receipt.transaction_hash},
        from(t in Chain.Transaction, where: t.hash == ^receipt.transaction_hash),
        [set: [gas_used_for_l1: receipt.gas_used_for_l1]]
      )
    end)
  end
end
