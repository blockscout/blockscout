# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Transform.EIP8430Transactions do
  @moduledoc """
    Helper functions for extracting the fields that only EIP-8430 transactions
    (EIP-2718 type `0x79`) have.
  """

  require Logger

  alias Explorer.Chain.{Data, EIP8430Transaction}

  @address_byte_length 20
  @zero_address_bytes <<0::160>>

  # The single byte that marks the open payer mode in the wire form of `payer`.
  @open_payer_bytes <<0>>

  @doc """
    Extracts the EIP-8430 fields from a list of transactions with receipts.

    The function keeps the transactions that have the `:eip_8430_fields` key and prepares one
    row for each of them. It stores the values of the node without interpretation, with two
    exceptions: it replaces `sender` with the `has_named_sender` flag, and it adds the
    `payer_type` label that tells what the `payer` value means.

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
            optional(any()) => any()
          }
        ]) :: [EIP8430Transaction.to_import()]
  def parse(transactions_with_receipts) do
    transactions_with_receipts
    |> Enum.filter(&Map.has_key?(&1, :eip_8430_fields))
    |> Enum.map(fn %{hash: transaction_hash, eip_8430_fields: fields} ->
      {payer_type, payer} = classify_payer(fields.payer, transaction_hash)

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
        account_changes: fields.account_changes
      }
    end)
  end

  # Tells whether the `sender` value of the transaction object is a 20-byte address. An absent
  # value, `nil`, and `0x` mean an empty sender: the node recovers the sender from the
  # authorization.
  @spec named_sender?(any(), EthereumJSONRPC.hash()) :: boolean()
  defp named_sender?(nil, _transaction_hash), do: false
  defp named_sender?("0x", _transaction_hash), do: false

  defp named_sender?(sender, transaction_hash) do
    case bytes(sender) do
      {:ok, <<_::binary-size(@address_byte_length)>>} ->
        true

      _ ->
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
    case bytes(payer) do
      {:ok, @open_payer_bytes} ->
        {:open, payer}

      {:ok, <<_::binary-size(@address_byte_length)>> = address_bytes} when address_bytes != @zero_address_bytes ->
        {:named, payer}

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

  # Decodes a hex string of bytes. Every other term is an error.
  @spec bytes(any()) :: {:ok, binary()} | :error
  defp bytes(value) do
    case Data.cast(value) do
      {:ok, %Data{bytes: bytes}} -> {:ok, bytes}
      _ -> :error
    end
  end
end
