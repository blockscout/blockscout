# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SignedAuthorization.Reader do
  @moduledoc """
  Reads signed authorization data from the database.
  """

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.{Block, Hash, SignedAuthorization, Transaction}
  alias Explorer.Repo

  @doc """
  Returns a stream of `Block.t()` for signed authorizations with missing statuses.

  ## Parameters

    - `initial`: The initial accumulator value for the stream.
    - `reducer`: A function that processes each entry in the stream, receiving
      the entry and the current accumulator, and returning a new accumulator.

  ## Returns

    - `{:ok, accumulator}`: The final accumulator value after streaming through
      the block numbers.
  """
  @spec stream_blocks_to_refetch_signed_authorizations_statuses(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator)
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_blocks_to_refetch_signed_authorizations_statuses(initial, reducer) when is_function(reducer, 2) do
    query =
      from(
        b in Block,
        join: t in assoc(b, :transactions),
        join: s in assoc(t, :signed_authorizations),
        where: is_nil(s.status) and b.consensus == true and b.refetch_needed == false,
        distinct: true,
        select: %{
          block_hash: b.hash,
          block_number: b.number
        }
      )

    query |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Returns latest successful authorizations for a list of addresses.

  Only authorizations of transactions in consensus blocks are counted. A status
  of an authorization in a block that lost consensus was calculated for a chain
  that is not canonical anymore.

  ## Parameters

    - `address_hashes`: The list of `authority` addresses to fetch authorizations for.

  ## Returns

    - `[%{authority: Hash.Address.t(), nonce: non_neg_integer()}]`: The list of latest
      successful authorizations and their nonces for the given addresses, if there are any.
  """
  @spec address_hashes_to_latest_authorizations([Hash.Address.t()]) :: [
          %{authority: Hash.Address.t(), nonce: non_neg_integer()}
        ]
  def address_hashes_to_latest_authorizations(address_hashes) do
    query =
      from(
        s in SignedAuthorization,
        join: t in assoc(s, :transaction),
        join: b in assoc(t, :block),
        where: s.authority in ^address_hashes and s.status == :ok and b.consensus == true,
        select: %{authority: s.authority, nonce: max(s.nonce)},
        group_by: s.authority
      )

    Repo.all(query)
  end

  @doc """
  Returns the block hash of each given transaction that is in a consensus block.

  A pending transaction and a transaction of a block that lost consensus are
  absent from the result.

  ## Parameters

    - `transaction_hashes`: The list of transaction hashes to look up.

  ## Returns

    - `%{Hash.Full.t() => Hash.Full.t()}`: The map from a transaction hash to
      the hash of the consensus block that contains the transaction.
  """
  @spec transaction_hashes_to_consensus_block_hashes([Hash.Full.t()]) :: %{Hash.Full.t() => Hash.Full.t()}
  def transaction_hashes_to_consensus_block_hashes([]), do: %{}

  def transaction_hashes_to_consensus_block_hashes(transaction_hashes) do
    query =
      from(
        t in Transaction,
        join: b in assoc(t, :block),
        where: t.hash in ^transaction_hashes and b.consensus == true,
        select: {t.hash, t.block_hash}
      )

    query
    |> Repo.all()
    |> Map.new()
  end
end
