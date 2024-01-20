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
      select: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{DenormalizationHelper, Hash, Transaction}
  alias Explorer.Chain.Beacon.{Blob, BlobTransaction}

  @spec blob(Hash.Full.t(), [Chain.api?()]) :: {:error, :not_found} | {:ok, Blob.t()}
  def blob(hash, options) when is_list(options) do
    Blob
    |> where(hash: ^hash)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  @spec blob_hash_to_transactions(Hash.Full.t(), [Chain.api?()]) :: [
          %{
            block_consensus: boolean(),
            transaction_hash: Hash.Full.t()
          }
        ]
  def blob_hash_to_transactions(hash, options) when is_list(options) do
    query =
      BlobTransaction
      |> where(type(^hash, Hash.Full) == fragment("any(blob_versioned_hashes)"))
      |> join(:inner, [bt], transaction in Transaction, on: bt.hash == transaction.hash)
      |> order_by([bt, transaction], desc: transaction.block_consensus, desc: transaction.block_number)
      |> limit(10)

    query_with_denormalization =
      if DenormalizationHelper.denormalization_finished?() do
        query
        |> select([bt, transaction], %{
          block_consensus: transaction.block_consensus,
          transaction_hash: transaction.hash
        })
      else
        query
        |> join(:inner, [bt, transaction], block in Block, on: block.hash == transaction.block_hash)
        |> select([bt, transaction, block], %{
          block_consensus: block.consensus,
          transaction_hash: transaction.hash
        })
      end

    query_with_denormalization |> select_repo(options).all()
  end

  @spec stream_missed_blob_transactions_timestamps(
          initial :: accumulator,
          reducer :: (entry :: Hash.Address.t(), accumulator -> accumulator),
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
      if DenormalizationHelper.denormalization_finished?() do
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
