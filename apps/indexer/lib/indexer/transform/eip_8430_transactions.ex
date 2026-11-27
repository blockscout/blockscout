# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Transform.EIP8430Transactions do
  @moduledoc """
    Helper functions for extracting the fields that only EIP-8430 transactions
    (EIP-2718 type `0x79`) have.
  """

  require Logger

  alias Explorer.Chain.{Data, EIP8430Transaction, Hash}

  # The length of an address string: `0x` and 40 hex digits.
  @address_string_length 42
  @zero_address_bytes <<0::160>>

  # The single byte that marks the open payer mode in the wire form of `payer`.
  @open_payer_bytes <<0>>

  @doc """
    Extracts the EIP-8430 fields from a list of transactions with receipts.

    The function keeps the transactions that have the `:eip_8430_fields` key and prepares one
    row for each of them. It stores the values of the node without interpretation, with two
    exceptions: it replaces `sender` with the `has_named_sender` flag, and it adds the
    `payer_type` label that tells what the `payer` value means.

    The function also reads the receipt fields from the `:eip_8430_receipt_fields` key: the
    resolved payer and the number of committed phases. If the key or one of its fields is
    absent, the value in the row is `nil`, and the import rejects the row.

    The function keeps the resolved payer without change if it is an address string: `0x` and
    40 hex digits. For every other value, the function writes a warning to the log and puts
    `nil` into the row, so the import rejects the row. `resolved_payers/1` uses the same rule.

    An unexpected form of `sender` or `payer` does not raise an error. The function writes a
    warning to the log, and the row gets `has_named_sender: false` or `payer_type: :unknown`.

    ## Parameters
    - `transactions_with_receipts`: A list of transactions with receipts.

    ## Returns
    A list of rows ready for database import.
  """
  @spec parse([
          %{
            optional(:eip_8430_fields) => EthereumJSONRPC.Transaction.eip_8430_fields(),
            optional(:eip_8430_receipt_fields) => EthereumJSONRPC.Receipt.eip_8430_receipt_fields(),
            optional(any()) => any()
          }
        ]) :: [EIP8430Transaction.to_import()]
  def parse(transactions_with_receipts) do
    transactions_with_receipts
    |> Enum.filter(&Map.has_key?(&1, :eip_8430_fields))
    |> Enum.map(fn %{hash: transaction_hash, eip_8430_fields: fields} = transaction ->
      {payer_type, payer} = classify_payer(fields.payer, transaction_hash)
      receipt_fields = Map.get(transaction, :eip_8430_receipt_fields, %{})

      %{
        transaction_hash: transaction_hash,
        has_named_sender: named_sender?(fields.sender, transaction_hash),
        nonce_key: fields.nonce_key,
        valid_after: fields.valid_after,
        valid_before: fields.valid_before,
        metadata: fields.metadata,
        payer_type: payer_type,
        payer: payer,
        sender_auth: fields.sender_auth,
        payer_auth: fields.payer_auth,
        account_changes: fields.account_changes,
        resolved_payer_address_hash: parse_resolved_payer(Map.get(receipt_fields, :payer), transaction_hash),
        committed_phases_count: Map.get(receipt_fields, :committed_phases)
      }
    end)
  end

  @doc """
    Extracts the resolved payers of EIP-8430 transactions from a list of transactions with
    receipts.

    The resolved payer is the account that pays the fee. The function reads it from the
    `:eip_8430_receipt_fields` key, so it is the payer that the node reports in the receipt,
    not the `payer` value of the transaction. For a transaction where the sender pays, the
    resolved payer is the sender.

    The function skips a transaction if it has no receipt fields, or if it has no block
    number, or if its payer is not an address string: `0x` and 40 hex digits. Such a payer
    must not go to the import of addresses. With `INDEXER_ENABLE_PARTIAL_ASYNC_IMPORT=true`,
    `Indexer.Fetcher.AddressImporter` gets the addresses before the block import rejects the
    block, and one incorrect hash makes each of its next imports fail.

    ## Parameters
    - `transactions_with_receipts`: A list of transactions with receipts.

    ## Returns
    A list with one entry for each resolved payer: its address and the block number of the
    transaction. The entries are ready for `Indexer.Transform.Addresses.extract_addresses/2`
    and `Indexer.Transform.AddressCoinBalances.params_set/1`.
  """
  @spec resolved_payers([
          %{
            optional(:eip_8430_receipt_fields) => EthereumJSONRPC.Receipt.eip_8430_receipt_fields(),
            optional(any()) => any()
          }
        ]) :: [%{address_hash: String.t(), block_number: non_neg_integer()}]
  def resolved_payers(transactions_with_receipts) do
    Enum.flat_map(transactions_with_receipts, fn
      %{eip_8430_receipt_fields: %{payer: payer}, block_number: block_number} when is_integer(block_number) ->
        case resolved_payer_address_hash(payer) do
          nil -> []
          address_hash -> [%{address_hash: address_hash, block_number: block_number}]
        end

      _transaction ->
        []
    end)
  end

  # Returns the value to store as the resolved payer of the row. An absent payer gives `nil`
  # without a warning. A payer that is not an address string gives `nil` with a warning: the
  # import error for the row is the same in the two cases, so only the warning shows the value
  # of the node.
  @spec parse_resolved_payer(any(), EthereumJSONRPC.hash()) :: String.t() | nil
  defp parse_resolved_payer(nil, _transaction_hash), do: nil

  defp parse_resolved_payer(payer, transaction_hash) do
    case resolved_payer_address_hash(payer) do
      nil ->
        Logger.warning(
          "Unexpected payer value #{inspect(payer)} in the receipt of EIP-8430 transaction #{transaction_hash}. The resolved payer is recorded as absent."
        )

        nil

      address_hash ->
        address_hash
    end
  end

  # Returns the resolved payer of the receipt if it is an address string, and `nil` for every
  # other term. `parse/1` and `resolved_payers/1` both use this function, so they have one
  # rule for the payer. The changeset of the row accepts more forms: an integer, and a binary
  # of 20 bytes. With `nil` in place of such a value, the import rejects the row.
  @spec resolved_payer_address_hash(any()) :: String.t() | nil
  defp resolved_payer_address_hash(payer) do
    case address_bytes(payer) do
      {:ok, _address_bytes} -> payer
      :error -> nil
    end
  end

  # Tells whether the `sender` value of the transaction object is a 20-byte address. An absent
  # value, `nil`, and `0x` mean an empty sender: the node recovers the sender from the
  # authorization.
  @spec named_sender?(any(), EthereumJSONRPC.hash()) :: boolean()
  defp named_sender?(nil, _transaction_hash), do: false
  defp named_sender?("0x", _transaction_hash), do: false

  defp named_sender?(sender, transaction_hash) do
    case address_bytes(sender) do
      {:ok, _address_bytes} ->
        true

      :error ->
        Logger.warning(
          "Unexpected sender value #{inspect(sender)} in EIP-8430 transaction #{transaction_hash}. The sender is recorded as not named."
        )

        false
    end
  end

  # Tells what the `payer` value of the transaction object means and returns the value to
  # store. The value stays as the node returned it. The only exception is a value that is not
  # a hex string of bytes: it cannot go to a `bytea` column, so `nil` replaces it.
  @spec classify_payer(any(), EthereumJSONRPC.hash()) :: {EIP8430Transaction.payer_type(), String.t() | nil}
  defp classify_payer(nil, _transaction_hash), do: {:self, nil}
  defp classify_payer("0x", _transaction_hash), do: {:self, "0x"}

  defp classify_payer(payer, transaction_hash) do
    case address_bytes(payer) do
      {:ok, address_bytes} when address_bytes != @zero_address_bytes -> {:named, payer}
      _ -> classify_non_address_payer(payer, transaction_hash)
    end
  end

  # Classifies a `payer` value that is not a non-zero 20-byte address.
  @spec classify_non_address_payer(any(), EthereumJSONRPC.hash()) ::
          {EIP8430Transaction.payer_type(), String.t() | nil}
  defp classify_non_address_payer(payer, transaction_hash) do
    case bytes(payer) do
      {:ok, @open_payer_bytes} ->
        {:open, payer}

      {:ok, _bytes} ->
        log_unknown_payer(payer, transaction_hash)
        {:unknown, payer}

      :error ->
        log_unknown_payer(payer, transaction_hash)
        {:unknown, nil}
    end
  end

  @spec log_unknown_payer(any(), EthereumJSONRPC.hash()) :: :ok
  defp log_unknown_payer(payer, transaction_hash) do
    Logger.warning(
      "Unexpected payer value #{inspect(payer)} in EIP-8430 transaction #{transaction_hash}. The payer type is recorded as unknown."
    )
  end

  # Decodes an address string: `0x` and 40 hex digits. Every other term is an error.
  #
  # The guard is necessary because `Hash.Address.cast/1` accepts more forms: an integer, and a
  # binary of 20 bytes that it takes as the raw bytes of the address.
  @spec address_bytes(any()) :: {:ok, <<_::160>>} | :error
  defp address_bytes("0x" <> _ = value) when byte_size(value) == @address_string_length do
    case Hash.Address.cast(value) do
      {:ok, %Hash{bytes: bytes}} -> {:ok, bytes}
      :error -> :error
    end
  end

  defp address_bytes(_value), do: :error

  # Decodes a hex string of bytes. Every other term is an error.
  @spec bytes(any()) :: {:ok, binary()} | :error
  defp bytes(value) do
    case Data.cast(value) do
      {:ok, %Data{bytes: bytes}} -> {:ok, bytes}
      _ -> :error
    end
  end
end
