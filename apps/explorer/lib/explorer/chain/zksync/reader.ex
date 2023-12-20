defmodule Explorer.Chain.ZkSync.Reader do
  @moduledoc "Contains read functions for zksync modules."

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 2,
      where: 2,
      where: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  # alias Explorer.Chain.Zkevm.{BatchTransaction, LifecycleTransaction, TransactionBatch}
  alias Explorer.Chain.ZkSync.{
    LifecycleTransaction,
    TransactionBatch
  }
  alias Explorer.{Chain, PagingOptions, Repo}

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

  def batch(number, options)
      when (is_integer(number) or is_binary(number)) and
           is_list(options) do
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

  def batches(start_number, end_number, options)
      when is_integer(start_number) and
           is_integer(end_number) and
           is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    from(tb in TransactionBatch, order_by: [desc: tb.number])
    |> where([tb], tb.number >= ^start_number and tb.number <= ^end_number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  def batches(numbers, options)
      when is_list(numbers) and
           is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    from(tb in TransactionBatch, order_by: [desc: tb.number])
    |> where([tb], tb.number in ^numbers)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  def batches(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    base_query =
      from(tb in TransactionBatch,
        order_by: [desc: tb.number]
      )

    query =
      if Keyword.get(options, :confirmed?, false) do
        base_query
        |> Chain.join_associations(necessity_by_association)
        |> where([tb], not is_nil(tb.commit_id) and tb.commit_id > 0)
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
    Gets the number of the earliest batch where commit_id is nil.
    Returns nil if not found
  """
  @spec earliest_sealed_batch_number() :: non_neg_integer() | nil
  def earliest_sealed_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        where: is_nil(tb.commit_id),
        order_by: [asc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(nil)
  end

  @doc """
    Gets the number of the earliest batch where prove_id is nil.
    Returns nil if not found
  """
  @spec earliest_unproven_batch_number() :: non_neg_integer() | nil
  def earliest_unproven_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        where: is_nil(tb.prove_id),
        order_by: [asc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(nil)
  end

  @doc """
    Gets the number of the earliest batch where execute_id is nil.
    Returns nil if not found
  """
  @spec earliest_unexecuted_batch_number() :: non_neg_integer() | nil
  def earliest_unexecuted_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        where: is_nil(tb.execute_id),
        order_by: [asc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(nil)
  end

  @doc """
    Gets the number of the oldest batch.
    Returns nil if not found
  """
  @spec oldest_available_batch_number() :: non_neg_integer() | nil
  def oldest_available_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        order_by: [asc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(nil)
  end

  @doc """
    Gets the number of the latest batch.
    Returns nil if not found
  """
  @spec latest_available_batch_number() :: non_neg_integer() | nil
  def latest_available_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        order_by: [desc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(nil)
  end

  @doc """
    Reads a list of L1 transactions by their hashes from `zksync_lifecycle_l1_transactions` table.
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
    Determines ID of the future lifecycle transaction by reading `zksync_lifecycle_l1_transactions` table.
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
