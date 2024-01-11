defmodule Explorer.Chain.Beacon.Reader do
  @moduledoc "Contains read functions for beacon chain related modules."

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 3,
      where: 2,
      where: 3,
      join: 5,
      select: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Beacon.{BlobTransaction, Blob}
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Transaction, Hash}

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

  def blobs_transactions(options) when is_list(options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    BlobTransaction
    |> join(:inner, [bt], transaction in Transaction, on: bt.hash == transaction.hash)
    |> where([bt, transaction], transaction.type == 3)
    |> order_by([bt, transaction], desc: transaction.block_number, desc: transaction.index)
    |> page_blobs_transactions(paging_options)
    |> limit(^paging_options.page_size)
    |> select([bt, transaction], %{
      block_number: transaction.block_number,
      index: transaction.index,
      blob_hashes: bt.blob_versioned_hashes,
      transaction_hash: bt.hash
    })
    |> select_repo(options).all()
  end

  defp page_blobs_transactions(query, %PagingOptions{key: nil}), do: query

  defp page_blobs_transactions(query, %PagingOptions{key: {block_number, index}}) do
    from([bt, transaction] in query,
      where: fragment("(?, ?) <= (?, ?)", transaction.block_number, transaction.index, ^block_number, ^index)
    )
  end
end
