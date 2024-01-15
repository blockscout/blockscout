defmodule Explorer.Chain.Beacon.Reader do
  @moduledoc "Contains read functions for beacon chain related modules."

  import Ecto.Query,
    only: [
      subquery: 1,
      preload: 2,
      from: 2,
      limit: 2,
      order_by: 3,
      where: 2,
      where: 3,
      join: 5,
      select: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Beacon.{Blob, BlobTransaction}
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Hash, Transaction}

  def blob(hash, options) when is_list(options) do
    Blob
    |> where(hash: ^hash)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  def blob_hash_to_transactions(hash, options) when is_list(options) do
    BlobTransaction
    |> where(type(^hash, Hash.Full) == fragment("any(blob_versioned_hashes)"))
    |> join(:inner, [bt], transaction in Transaction, on: bt.hash == transaction.hash)
    |> order_by([bt, transaction], desc: transaction.block_consensus, desc: transaction.block_number)
    |> limit(10)
    |> select([bt, transaction], %{
      block_consensus: transaction.block_consensus,
      transaction_hash: transaction.hash
    })
    |> select_repo(options).all()
  end

  def stream_missed_blob_transactions_timestamps(min_block, max_block, initial, reducer, options \\ [])
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
        where: transaction.type == 3,
        left_join: blob in Blob,
        on: blob.hash == transaction_blob.blob_hash,
        where: is_nil(blob.hash),
        distinct: transaction.block_timestamp,
        select: transaction.block_timestamp
      )

    query
    |> add_min_block_filter(min_block)
    |> add_max_block_filter(min_block)
    |> Repo.stream_reduce(initial, reducer)
  end

  defp add_min_block_filter(query, block_number) do
    if is_integer(block_number) do
      query |> where([_, transaction], transaction.block_number <= ^block_number)
    else
      query
    end
  end

  defp add_max_block_filter(query, block_number) do
    if is_integer(block_number) and block_number > 0 do
      query |> where([_, transaction], transaction.block_number >= ^block_number)
    else
      query
    end
  end
end
