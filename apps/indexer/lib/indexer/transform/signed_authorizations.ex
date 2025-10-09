defmodule Indexer.Transform.SignedAuthorizations do
  @moduledoc """
    Helper functions for extracting signed authorizations from EIP-7702 transactions.
  """

  alias Explorer.Chain.{Hash, SignedAuthorization}

  # The magic number used in EIP-7702 to prefix the message to be signed.
  @eip7702_magic 0x5

  @doc """
    Extracts signed authorizations from a list of transactions with receipts.

    This function parses the authorization tuples from EIP-7702 set code transactions,
    recovers the authority address from the signature, and prepares the data for database import.

    ## Parameters
    - `transactions_with_receipts`: A list of transactions with receipts.

    ## Returns
    A list of signed authorizations ready for database import.
  """
  @spec parse([
          %{optional(:authorization_list) => [EthereumJSONRPC.SignedAuthorization.params()], optional(any()) => any()}
        ]) :: [SignedAuthorization.to_import()]
  def parse(transactions_with_receipts) do
    transactions_with_receipts
    |> Enum.filter(&Map.has_key?(&1, :authorization_list))
    |> Enum.flat_map(
      &(&1.authorization_list
        |> Enum.with_index()
        |> Enum.map(fn {authorization, index} ->
          new_authorization =
            authorization
            |> Map.merge(%{
              transaction_hash: &1.hash,
              index: index,
              authority: recover_authority(authorization)
            })

          # we can immediately do some basic validation that doesn't require any extra JSON-RPC requests
          # full validation for :invalid_nonce is deferred to async fetcher (so :ok is replaced with nil)
          status =
            case SignedAuthorization.basic_validate(new_authorization) do
              :ok -> nil
              status -> status
            end

          new_authorization
          |> Map.put(:status, status)
        end))
    )
  end

  # This function recovers the signer address from the signed authorization data using this formula:
  #   authority = ecrecover(keccak(MAGIC || rlp([chain_id, address, nonce])), y_parity, r, s]
  @spec recover_authority(EthereumJSONRPC.SignedAuthorization.params()) :: String.t() | nil
  defp recover_authority(signed_authorization) do
    {:ok, %{bytes: address}} = Hash.Address.cast(signed_authorization.address)

    signed_message =
      ExKeccak.hash_256(
        <<@eip7702_magic>> <> ExRLP.encode([signed_authorization.chain_id, address, signed_authorization.nonce])
      )

    authority =
      ec_recover(signed_message, signed_authorization.r, signed_authorization.s, signed_authorization.v)

    authority
  end

  # This function uses elliptic curve recovery to get the address from the signed message and the signature.
  @spec ec_recover(binary(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: EthereumJSONRPC.address() | nil
  defp ec_recover(signed_message, r, s, v) do
    r_bytes = <<r::integer-size(256)>>
    s_bytes = <<s::integer-size(256)>>

    with {:ok, <<_compression::bytes-size(1), public_key::binary>>} <-
           ExSecp256k1.recover(signed_message, r_bytes, s_bytes, v),
         <<_::bytes-size(12), hash::binary>> <- ExKeccak.hash_256(public_key) do
      address = Base.encode16(hash, case: :lower)
      "0x" <> address
    else
      _ -> nil
    end
  end
end
