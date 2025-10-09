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

  alias Explorer.Chain.ZkSync.{
    BatchTransaction,
    LifecycleTransaction,
    TransactionBatch
  }

  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Prometheus.Instrumenter

  @doc """
    Receives total amount of batches imported to the `zksync_transaction_batches` table.

    ## Parameters
    - `options`: passed to `Chain.select_repo()`

    ## Returns
    Total amount of batches
  """
  @spec batches_count(keyword()) :: any()
  def batches_count(options) do
    TransactionBatch
    |> select_repo(options).aggregate(:count, timeout: :infinity)
  end

  @doc """
    Receives the batch from the `zksync_transaction_batches` table by using its number or the latest batch if `:latest` is used.

    ## Parameters
    - `number`: could be either the batch number or `:latest` to get the latest available in DB batch
    - `options`: passed to `Chain.select_repo()`

    ## Returns
    - `{:ok, Explorer.Chain.ZkSync.TransactionBatch}` if the batch found
    - `{:error, :not_found}` if there is no batch with such number
  """
  @spec batch(:latest | binary() | integer(), keyword()) ::
          {:error, :not_found} | {:ok, Explorer.Chain.ZkSync.TransactionBatch}
  def batch(number, options)

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

  @doc """
    Receives a list of batches from the `zksync_transaction_batches` table within the range of batch numbers

    ## Parameters
    - `start_number`: The start of the batch numbers range.
    - `end_number`: The end of the batch numbers range.
    - `options`: Options passed to `Chain.select_repo()`.

    ## Returns
    - A list of `Explorer.Chain.ZkSync.TransactionBatch` if at least one batch exists within the range.
    - An empty list (`[]`) if no batches within the range are found in the database.
  """
  @spec batches(integer(), integer(), keyword()) :: [Explorer.Chain.ZkSync.TransactionBatch]
  def batches(start_number, end_number, options)
      when is_integer(start_number) and
             is_integer(end_number) and
             is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    base_query = from(tb in TransactionBatch, order_by: [desc: tb.number])

    base_query
    |> where([tb], tb.number >= ^start_number and tb.number <= ^end_number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  @doc """
    Receives a list of batches from the `zksync_transaction_batches` table with the numbers defined in the input list.

    ## Parameters
    - `numbers`: The list of batch numbers to retrieve from the database.
    - `options`: Options passed to `Chain.select_repo()`.

    ## Returns
    - A list of `Explorer.Chain.ZkSync.TransactionBatch` if at least one batch matches the numbers from the list. The output list could be less than the input list.
    - An empty list (`[]`) if no batches with numbers from the list are found.
  """
  @spec batches(maybe_improper_list(integer(), []), keyword()) :: [Explorer.Chain.ZkSync.TransactionBatch]
  def batches(numbers, options)
      when is_list(numbers) and
             is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    base_query = from(tb in TransactionBatch, order_by: [desc: tb.number])

    base_query
    |> where([tb], tb.number in ^numbers)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  @doc """
    Receives a list of batches from the `zksync_transaction_batches` table.

    ## Parameters
    - `options`: Options passed to `Chain.select_repo()`. (Optional)

    ## Returns
    - If the option `confirmed?` is set, returns the ten latest committed batches (`Explorer.Chain.ZkSync.TransactionBatch`).
    - Returns a list of `Explorer.Chain.ZkSync.TransactionBatch` based on the paging options if `confirmed?` is not set.
  """
  @spec batches(keyword()) :: [Explorer.Chain.ZkSync.TransactionBatch]
  @spec batches() :: [Explorer.Chain.ZkSync.TransactionBatch]
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

        case paging_options do
          %PagingOptions{key: {0}} ->
            []

          _ ->
            base_query
            |> Chain.join_associations(necessity_by_association)
            |> page_batches(paging_options)
            |> limit(^paging_options.page_size)
        end
      end

    select_repo(options).all(query)
  end

  @doc """
    Receives a list of transactions from the `zksync_batch_l2_transactions` table included in a specific batch.

    ## Parameters
    - `batch_number`: The number of batch which transactions were included to L1 as part of.
    - `options`: Options passed to `Chain.select_repo()`. (Optional)

    ## Returns
    - A list of `Explorer.Chain.ZkSync.BatchTransaction` belonging to the specified batch.
  """
  @spec batch_transactions(non_neg_integer()) :: [Explorer.Chain.ZkSync.BatchTransaction]
  @spec batch_transactions(non_neg_integer(), keyword()) :: [Explorer.Chain.ZkSync.BatchTransaction]
  def batch_transactions(batch_number, options \\ [])
      when is_integer(batch_number) or
             is_binary(batch_number) do
    query = from(batch in BatchTransaction, where: batch.batch_number == ^batch_number)

    select_repo(options).all(query)
  end

  @doc """
    Gets the number of the earliest batch in the `zksync_transaction_batches` table where the commitment transaction is not set.
    Batch #0 is filtered out, as it does not have a linked commitment transaction.

    ## Returns
    - The number of a batch if it exists, otherwise `nil`. `nil` could mean either no batches imported yet or all imported batches are marked as committed or Batch #0 is the only available batch.
  """
  @spec earliest_sealed_batch_number() :: non_neg_integer() | nil
  def earliest_sealed_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        where: is_nil(tb.commit_id) and tb.number > 0,
        order_by: [asc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
  end

  @doc """
    Gets the number of the earliest batch in the `zksync_transaction_batches` table where the proving transaction is not set.
    Batch #0 is filtered out, as it does not have a linked proving transaction.

    ## Returns
    - The number of a batch if it exists, otherwise `nil`. `nil` could mean either no batches imported yet or all imported batches are marked as proven or Batch #0 is the only available batch.
  """
  @spec earliest_unproven_batch_number() :: non_neg_integer() | nil
  def earliest_unproven_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        where: is_nil(tb.prove_id) and tb.number > 0,
        order_by: [asc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
  end

  @doc """
    Gets the number of the earliest batch in the `zksync_transaction_batches` table where the executing transaction is not set.
    Batch #0 is filtered out, as it does not have a linked executing transaction.

    ## Returns
    - The number of a batch if it exists, otherwise `nil`. `nil` could mean either no batches imported yet or all imported batches are marked as executed or Batch #0 is the only available batch.
  """
  @spec earliest_unexecuted_batch_number() :: non_neg_integer() | nil
  def earliest_unexecuted_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        where: is_nil(tb.execute_id) and tb.number > 0,
        order_by: [asc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
  end

  @doc """
    Gets the number of the oldest batch from the `zksync_transaction_batches` table.

    ## Returns
    - The number of a batch if it exists, otherwise `nil`. `nil` means that there is no batches imported yet.
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
  end

  @doc """
    Gets the number of the youngest (the most recent) imported batch from the `zksync_transaction_batches` table.

    ## Returns
    - The number of a batch if it exists, otherwise `nil`. `nil` means that there is no batches imported yet.
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
  end

  @doc """
    Reads a list of L1 transactions by their hashes from the `zksync_lifecycle_l1_transactions` table.

    ## Parameters
    - `l1_transaction_hashes`: A list of hashes to retrieve L1 transactions for.

    ## Returns
    - A list of `Explorer.Chain.ZkSync.LifecycleTransaction` corresponding to the hashes from the input list. The output list may be smaller than the input list.
  """
  @spec lifecycle_transactions(maybe_improper_list(binary(), [])) :: [Explorer.Chain.ZkSync.LifecycleTransaction]
  def lifecycle_transactions(l1_transaction_hashes) do
    query =
      from(
        lt in LifecycleTransaction,
        select: {lt.hash, lt.id},
        where: lt.hash in ^l1_transaction_hashes
      )

    Repo.all(query, timeout: :infinity)
  end

  @doc """
    Determines the next index for the L1 transaction available in the `zksync_lifecycle_l1_transactions` table.

    ## Returns
    - The next available index. If there are no L1 transactions imported yet, it will return `1`.
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

  @doc """
    Gets information about the latest batch and calculates average time between commitments.

    ## Parameters
      - `options`: Options passed to `Chain.select_repo()`. (Optional)

    ## Returns
    - If batches exist and at least one batch is committed:
      `{:ok, %{latest_batch_number: integer, latest_batch_timestamp: DateTime.t(), average_batch_time: integer}}`
      where:
        * latest_batch_number - number of the latest batch in the database
        * latest_batch_timestamp - when the latest batch was committed to L1
        * average_batch_time - average number of seconds between commits for the last 10 batches

    - If no committed batches exist: `{:error, :not_found}`
  """
  @spec get_latest_batch_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_batch_info(options \\ []) do
    import Ecto.Query

    latest_batches_query =
      from(batch in TransactionBatch,
        join: tx in assoc(batch, :commit_transaction),
        order_by: [desc: batch.number],
        limit: 10,
        select: %{
          number: batch.number,
          timestamp: tx.timestamp
        }
      )

    items = select_repo(options).all(latest_batches_query)
    Instrumenter.prepare_batch_metric(items)
  end
end
