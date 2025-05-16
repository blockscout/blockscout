defmodule Explorer.Chain.Beacon.Reader do
  @moduledoc "Contains read functions for beacon chain related modules."

  import Ecto.Query,
    only: [
      subquery: 1,
      distinct: 3,
      from: 2,
      limit: 2,
      order_by: 3,
      where: 2,
      where: 3,
      join: 5,
      select: 3,
      select_merge: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, DenormalizationHelper, Hash, Transaction}
  alias Explorer.Chain.Beacon.{Blob, BlobTransaction}

  @doc """
  Finds `t:Explorer.Chain.Beacon.Blob.t/0` by its `hash`.

  Returns `{:ok, %Explorer.Chain.Beacon.Blob{}}` if found

      iex> %Explorer.Chain.Beacon.Blob{hash: hash} = insert(:blob)
      iex> {:ok, %Explorer.Chain.Beacon.Blob{hash: found_hash}} = Explorer.Chain.Beacon.Reader.blob(hash, true)
      iex> found_hash == hash
      true

  Returns `{:error, :not_found}` if not found

      iex> {:ok, hash} = Explorer.Chain.string_to_full_hash(
      ...>   "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b"
      ...> )
      iex> Explorer.Chain.Beacon.Reader.blob(hash, true)
      {:error, :not_found}

  """
  @spec blob(Hash.Full.t(), boolean(), [Chain.api?()]) :: {:error, :not_found} | {:ok, Blob.t()}
  def blob(hash, with_data, options \\ []) when is_list(options) do
    query =
      if with_data do
        Blob
        |> where(hash: ^hash)
      else
        Blob
        |> where(hash: ^hash)
        |> select_merge([_], %{blob_data: nil})
      end

    query
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      blob -> {:ok, blob}
    end
  end

  @doc """
  Finds all `t:Explorer.Chain.Beacon.Blob.t/0`s for `t:Explorer.Chain.Transaction.t/0`.

  Returns a list of `%Explorer.Chain.Beacon.Blob{}` belonging to the given `transaction_hash`.

      iex> blob = insert(:blob)
      iex> %Explorer.Chain.Beacon.BlobTransaction{hash: transaction_hash} = insert(:blob_transaction, blob_versioned_hashes: [blob.hash])
      iex> blobs = Explorer.Chain.Beacon.Reader.transaction_to_blobs(transaction_hash)
      iex> blobs == [%{hash: blob.hash, blob_data: blob.blob_data, kzg_commitment: blob.kzg_commitment, kzg_proof: blob.kzg_proof}]
      true

  """
  @spec transaction_to_blobs(Hash.Full.t(), [Chain.api?()]) :: [Blob.t()]
  def transaction_to_blobs(transaction_hash, options \\ []) when is_list(options) do
    query =
      from(
        transaction_blob in subquery(
          from(
            blob_transaction in BlobTransaction,
            select: %{
              hash: fragment("unnest(blob_versioned_hashes)"),
              idx: fragment("generate_series(1, array_length(blob_versioned_hashes, 1))")
            },
            where: blob_transaction.hash == ^transaction_hash
          )
        ),
        left_join: blob in Blob,
        on: blob.hash == transaction_blob.hash,
        select: %{
          hash: type(transaction_blob.hash, Hash.Full),
          blob_data: blob.blob_data,
          kzg_commitment: blob.kzg_commitment,
          kzg_proof: blob.kzg_proof
        },
        order_by: transaction_blob.idx
      )

    query
    |> select_repo(options).all()
  end

  @doc """
  Finds associated transaction hashes for the given blob `hash` identifier. Returns at most 10 matches.

  Returns a list of `%{block_consensus: boolean(), transaction_hash: Hash.Full.t()}` maps for all found transactions.

      iex> %Explorer.Chain.Beacon.Blob{hash: blob_hash} = insert(:blob)
      iex> %Explorer.Chain.Beacon.BlobTransaction{hash: transaction_hash} = insert(:blob_transaction, blob_versioned_hashes: [blob_hash])
      iex> blob_transactions = Explorer.Chain.Beacon.Reader.blob_hash_to_transactions(blob_hash)
      iex> blob_transactions == [%{block_consensus: true, transaction_hash: transaction_hash}]
      true
  """
  @spec blob_hash_to_transactions(Hash.Full.t(), [Chain.api?()]) :: [
          %{
            block_consensus: boolean(),
            transaction_hash: Hash.Full.t()
          }
        ]
  def blob_hash_to_transactions(hash, options \\ []) when is_list(options) do
    query =
      BlobTransaction
      |> where(type(^hash, Hash.Full) == fragment("any(blob_versioned_hashes)"))
      |> join(:inner, [bt], transaction in Transaction, on: bt.hash == transaction.hash)
      |> limit(10)

    query_with_denormalization =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        query
        |> order_by([bt, transaction], desc: transaction.block_consensus, desc: transaction.block_number)
        |> select([bt, transaction], %{
          block_consensus: transaction.block_consensus,
          transaction_hash: transaction.hash
        })
      else
        query
        |> join(:inner, [bt, transaction], block in Block, on: block.hash == transaction.block_hash)
        |> order_by([bt, transaction, block], desc: block.consensus, desc: transaction.block_number)
        |> select([bt, transaction, block], %{
          block_consensus: block.consensus,
          transaction_hash: transaction.hash
        })
      end

    query_with_denormalization |> select_repo(options).all()
  end

  @doc """
  Returns a stream of all unique block timestamps containing missing data blobs.
  Filters blocks by `min_block` and `max_block` if provided.
  """
  @spec stream_missed_blob_transactions_timestamps(
          initial :: accumulator,
          reducer :: (entry :: DateTime.t(), accumulator -> accumulator),
          min_block :: integer() | nil,
          max_block :: integer() | nil,
          options :: []
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_missed_blob_transactions_timestamps(initial, reducer, min_block, max_block, options \\ [])
      when is_list(options) do
    query =
      from(
        transaction_blob in subquery(
          from(
            blob_transaction in BlobTransaction,
            select: %{
              transaction_hash: blob_transaction.hash,
              blob_hash: fragment("unnest(blob_versioned_hashes)")
            }
          )
        ),
        inner_join: transaction in Transaction,
        on: transaction_blob.transaction_hash == transaction.hash,
        # EIP-2718 blob transaction type
        where: transaction.type == 3,
        left_join: blob in Blob,
        on: blob.hash == transaction_blob.blob_hash,
        where: is_nil(blob.hash)
      )

    query_with_denormalization =
      if DenormalizationHelper.transactions_denormalization_finished?() do
        query
        |> distinct([transaction_blob, transaction, blob], transaction.block_timestamp)
        |> select([transaction_blob, transaction, blob], transaction.block_timestamp)
      else
        query
        |> join(:inner, [transaction_blob, transaction, blob], block in Block, on: block.hash == transaction.block_hash)
        |> distinct([transaction_blob, transaction, blob, block], block.timestamp)
        |> select([transaction_blob, transaction, blob, block], block.timestamp)
      end

    query_with_denormalization
    |> add_min_block_filter(min_block)
    |> add_max_block_filter(max_block)
    |> Repo.stream_reduce(initial, reducer)
  end

  defp add_min_block_filter(query, block_number) do
    if is_integer(block_number) do
      query |> where([_, transaction], transaction.block_number >= ^block_number)
    else
      query
    end
  end

  defp add_max_block_filter(query, block_number) do
    if is_integer(block_number) and block_number > 0 do
      query |> where([_, transaction], transaction.block_number <= ^block_number)
    else
      query
    end
  end
end
