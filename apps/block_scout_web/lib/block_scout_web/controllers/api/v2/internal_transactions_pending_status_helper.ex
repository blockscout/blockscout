# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.InternalTransactionsPendingStatusHelper do
  @moduledoc """
  Helpers for calculating whether internal-transactions API v2 responses should
  include the pending-processing status metadata.
  """

  alias Explorer.Chain.PendingOperationsHelper

  @pending_message "Some internal transactions within this block range have not yet been processed"

  @doc """
  Returns the standard message used when internal transactions are still pending processing.
  """
  def pending_message, do: @pending_message

  @doc """
  Checks whether the global internal-transactions endpoint scope contains pending operations.
  """
  @spec internal_transactions_pending?(list(), any() | nil) :: boolean()
  def internal_transactions_pending?(internal_transactions, transaction_hash \\ nil) do
    {min_block_number, max_block_number} =
      internal_transactions
      |> extract_block_numbers()
      |> expand_block_range()
      |> then(&(&1 || {nil, nil}))

    # Tx hashes extracted from the fetched page are already within the page's block range, so
    # they are covered by the block-range PTO check inside
    # pending_operations_for_block_range_or_transactions?/3.
    # Only the explicit transaction_hash (which may fall outside the page's range) is passed
    # separately so it is still checked even when the block range wouldn't cover it.
    PendingOperationsHelper.pending_operations_for_block_range_or_transactions?(
      min_block_number,
      max_block_number,
      maybe_prepend_hash([], transaction_hash)
    )
  end

  @doc """
  Checks whether the address internal-transactions endpoint scope contains pending operations.

  Only checks block-range pending operations — tx-hash checking is not meaningful here
  because internal transactions are imported atomically per transaction: if any internal
  transaction exists for a given tx_hash, all of them are already imported.
  """
  @spec address_internal_transactions_pending?(list()) :: boolean()
  def address_internal_transactions_pending?(internal_transactions) do
    {min_block_number, max_block_number} =
      internal_transactions
      |> extract_block_numbers()
      |> expand_block_range()
      |> then(&(&1 || {nil, nil}))

    PendingOperationsHelper.pending_operations_in_block_range?(min_block_number, max_block_number)
  end

  @doc """
  Checks whether the block internal-transactions endpoint scope contains pending operations.

  It verifies both pending block operations for the block number itself and pending
  transaction operations associated with that block.
  """
  @spec block_internal_transactions_pending?(list(), non_neg_integer()) :: boolean()
  def block_internal_transactions_pending?(_internal_transactions, block_number) do
    # pending_operations_in_block_range?/2 checks both PBO (block pending) and PTO (any
    # transaction in that block still pending). Checking tx hashes individually would be
    # redundant — all fetched internal-tx hashes belong to that block and are already
    # covered by the PTO block-range check.
    PendingOperationsHelper.pending_operations_in_block_range?(block_number, block_number)
  end

  @doc """
  Checks whether the transaction internal-transactions endpoint scope contains pending operations.

  The check includes the requested transaction hash and block number together with
  hashes and block numbers extracted from the returned internal transactions.
  """
  @spec transaction_internal_transactions_pending?(list(), any(), non_neg_integer() | nil) :: boolean()
  def transaction_internal_transactions_pending?(internal_transactions, transaction_hash, block_number) do
    transaction_hashes =
      internal_transactions
      |> extract_transaction_hashes()
      |> maybe_prepend_hash(transaction_hash)

    block_numbers =
      internal_transactions
      |> extract_block_numbers()
      |> maybe_prepend_block_number(block_number)

    PendingOperationsHelper.pending_operations_for_blocks_or_transactions?(block_numbers, transaction_hashes)
  end

  defp maybe_prepend_hash(transaction_hashes, nil), do: transaction_hashes

  defp maybe_prepend_hash(transaction_hashes, transaction_hash) do
    [transaction_hash | transaction_hashes] |> Enum.uniq()
  end

  defp maybe_prepend_block_number(block_numbers, nil), do: block_numbers

  defp maybe_prepend_block_number(block_numbers, block_number) do
    [block_number | block_numbers] |> Enum.uniq()
  end

  defp extract_block_numbers(internal_transactions) do
    internal_transactions
    |> Enum.map(& &1.block_number)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_transaction_hashes(internal_transactions) do
    internal_transactions
    |> Enum.map(& &1.transaction_hash)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp expand_block_range([]), do: nil

  defp expand_block_range(block_numbers) do
    Enum.min_max(block_numbers)
  end
end
