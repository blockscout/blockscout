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

  @doc """
    Reads a batch by its number from database.
    If the number is :latest, gets the latest batch from `zkevm_transaction_batches` table.
    Returns {:error, :not_found} in case the batch is not found.
  """
  @spec batch(non_neg_integer() | :latest, list()) :: {:ok, map()} | {:error, :not_found}
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

  @doc """
    Reads a list of batches from `zkevm_transaction_batches` table.
  """
  @spec batches(list()) :: list()
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

  @doc """
    Reads a list of L2 transaction hashes from `zkevm_batch_l2_transactions` table.
  """
  @spec batch_transactions(non_neg_integer(), list()) :: list()
  def batch_transactions(batch_number, options \\ []) do
    query = from(bts in BatchTransaction, where: bts.batch_number == ^batch_number)

    select_repo(options).all(query)
  end

  @doc """
    Gets the number of the latest batch with defined verify_id from `zkevm_transaction_batches` table.
    Returns 0 if not found.
  """
  @spec last_verified_batch_number() :: non_neg_integer()
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

  @doc """
    Reads a list of L1 transactions by their hashes from `zkevm_lifecycle_l1_transactions` table.
  """
  @spec lifecycle_transactions(list()) :: list()
  def lifecycle_transactions(l1_tx_hashes) do
    query =
      from(
        lt in LifecycleTransaction,
        select: {lt.hash, lt.id},
        where: lt.hash in ^l1_tx_hashes
      )

    Repo.all(query, timeout: :infinity)
  end

  @doc """
    Determines ID of the future lifecycle transaction by reading `zkevm_lifecycle_l1_transactions` table.
  """
  @spec next_id() :: non_neg_integer()
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
