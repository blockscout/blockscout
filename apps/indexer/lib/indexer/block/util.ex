defmodule Indexer.Block.Util do
  @moduledoc """
  Helper functions for parsing block information.
  """

  @doc """
  Calculates the signer's address by recovering the ECDSA public key.

  https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm
  """
  def signer(block) when is_map(block) do
    # Last 65 bytes is the signature. Multiply by two since we haven't transformed to raw bytes
    {extra_data, signature} = String.split_at(trim_prefix(block.extra_data), -130)

    block = %{block | extra_data: extra_data}

    signature_hash = signature_hash(block)

    recover_pub_key(signature_hash, decode(signature))
  end

  # Signature hash calculated from the block header.
  # Needed for PoA-based chains
  defp signature_hash(block) do
    header_data = [
      decode(block.parent_hash),
      decode(block.sha3_uncles),
      decode(block.miner_hash),
      decode(block.state_root),
      decode(block.transactions_root),
      decode(block.receipts_root),
      decode(block.logs_bloom),
      block.difficulty,
      block.number,
      block.gas_limit,
      block.gas_used,
      DateTime.to_unix(block.timestamp),
      decode(block.extra_data),
      decode(block.mix_hash),
      decode(block.nonce)
    ]

    :keccakf1600.hash(:sha3_256, ExRLP.encode(header_data))
  end

  defp trim_prefix("0x" <> rest), do: rest

  defp decode("0x" <> rest) do
    decode(rest)
  end

  defp decode(data) do
    Base.decode16!(data, case: :mixed)
  end

  # Recovers the key from the signature hash and signature
  defp recover_pub_key(signature_hash, signature) do
    <<
      r::bytes-size(32),
      s::bytes-size(32),
      v::integer-size(8)
    >> = signature

    case :libsecp256k1.ecdsa_recover_compact(signature_hash, r <> s, :uncompressed, v) do
      {:ok, <<_compression::bytes-size(1), private_key::binary>>} ->
        # First byte represents compression which can be ignored
        # Private key is the last 64 bytes
        <<_::bytes-size(12), public_key::binary>> = :keccakf1600.hash(:sha3_256, private_key)
        miner_address = Base.encode16(public_key, case: :lower)
        "0x" <> miner_address
      {:error, _} ->
        # Unable to recover the signer's address so return the burn address.
        # This seems to be an issue when using the Clique block transformer.
        # Genesis block is the block that throws this error.
        "0x0000000000000000000000000000000000000000"
    end
  end
end
