defmodule Explorer.Chain.Zkevm.Reader do
  @moduledoc "Contains read functions for zkevm modules."

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 2,
      where: 2,
      where: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Zkevm.{BatchTransaction, LifecycleTransaction, TransactionBatch}
  alias Explorer.{Chain, PagingOptions, Repo}

  def batch(number, options \\ [])

  def batch(:latest, options) when is_list(options) do
    TransactionBatch
    |> order_by(desc: :number)
    |> limit(1)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  def batch(number, options) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    TransactionBatch
    |> where(number: ^number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  def batches(options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    base_query =
      from(tb in TransactionBatch,
        order_by: [desc: tb.number]
      )

    query =
      if Keyword.get(options, :confirmed?, false) do
        base_query
        |> Chain.join_associations(necessity_by_association)
        |> where([tb], not is_nil(tb.sequence_id) and tb.sequence_id > 0)
        |> limit(10)
      else
        paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

        base_query
        |> Chain.join_associations(necessity_by_association)
        |> page_batches(paging_options)
        |> limit(^paging_options.page_size)
      end

    select_repo(options).all(query)
  end

  def batch_transactions(batch_number, options \\ []) do
    query = from(bts in BatchTransaction, where: bts.batch_number == ^batch_number)

    select_repo(options).all(query)
  end

  def last_verified_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        where: not is_nil(tb.verify_id),
        order_by: [desc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(0)
  end

  def lifecycle_transactions(l1_tx_hashes) do
    query =
      from(
        lt in LifecycleTransaction,
        select: {lt.hash, lt.id},
        where: lt.hash in ^l1_tx_hashes
      )

    Repo.all(query, timeout: :infinity)
  end

  def next_id do
    query =
      from(lt in LifecycleTransaction,
        select: lt.id,
        order_by: [desc: lt.id],
        limit: 1
      )

    last_id =
      query
      |> Repo.one()
      |> Kernel.||(0)

    last_id + 1
  end

  defp page_batches(query, %PagingOptions{key: nil}), do: query

  defp page_batches(query, %PagingOptions{key: {number}}) do
    from(tb in query, where: tb.number < ^number)
  end
end
