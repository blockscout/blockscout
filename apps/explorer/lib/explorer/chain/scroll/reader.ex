defmodule Explorer.Chain.Scroll.Reader do
  @moduledoc "Contains read functions for Scroll modules."

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 2,
      order_by: 3,
      select: 3,
      where: 2,
      where: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Scroll.{Batch, BatchBundle, Bridge, L1FeeParam}
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Prometheus.Instrumenter

  @doc """
    Reads a batch by its number from database.

    ## Parameters
    - `number`: The batch number. If `:latest`, the function gets
                the latest batch from the `scroll_batches` table.
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - {:ok, batch} when the batch is found in the table.
    - {:error, :not_found} when the batch is not found.
  """
  @spec batch(non_neg_integer() | :latest,
          necessity_by_association: %{atom() => :optional | :required},
          api?: boolean()
        ) :: {:ok, Batch.t()} | {:error, :not_found}
  @spec batch(non_neg_integer() | :latest) :: {:ok, Batch.t()} | {:error, :not_found}
  def batch(number, options \\ [])

  def batch(:latest, options) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Batch
    |> order_by(desc: :number)
    |> limit(1)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  def batch(number, options) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    Batch
    |> where(number: ^number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  @doc """
    Lists `t:Explorer.Chain.Scroll.Batch.t/0`'s' in descending order based on the `number`.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database and paging options.

    ## Returns
    - A list of found entities sorted by `number` in descending order.
  """
  @spec batches(paging_options: PagingOptions.t(), api?: boolean()) :: [Batch.t()]
  @spec batches() :: [Batch.t()]
  def batches(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(b in Batch,
            order_by: [desc: b.number]
          )

        base_query
        |> Chain.join_association(:bundle, :optional)
        |> page_batches(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  @doc """
    Retrieves a list of rollup blocks included into a specified batch.

    This function constructs and executes a database query to retrieve a list of rollup blocks,
    considering pagination options specified in the `options` parameter. These options dictate
    the number of items to retrieve and how many items to skip from the top.

    ## Parameters
    - `batch_number`: The batch number.
    - `options`: A keyword list of options specifying pagination, association necessity, and
      whether to use a replica database.

    ## Returns
    - A list of `Explorer.Chain.Block` entries belonging to the specified batch.
  """
  @spec batch_blocks(non_neg_integer() | binary(),
          necessity_by_association: %{atom() => :optional | :required},
          api?: boolean(),
          paging_options: PagingOptions.t()
        ) :: [Block.t()]
  def batch_blocks(batch_number, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    api = Keyword.get(options, :api?, false)

    case batch(batch_number, api?: api) do
      {:ok, batch} ->
        query =
          from(
            b in Block,
            where:
              b.number >= ^batch.l2_block_range.from and b.number <= ^batch.l2_block_range.to and b.consensus == true
          )

        query
        |> page_batch_blocks(paging_options)
        |> limit(^paging_options.page_size)
        |> order_by(desc: :number)
        |> Chain.join_associations(necessity_by_association)
        |> select_repo(options).all()

      _ ->
        []
    end
  end

  @doc """
    Gets batch number and its bundle id (if defined) by the L2 block number.

    ## Parameters
    - `block_number`: The L2 block number for which the batch should be determined.
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - A tuple `{batch_number, bundle_id}`.
    - `nil` if the batch is not found.
  """
  @spec batch_by_l2_block_number(non_neg_integer()) :: {non_neg_integer(), non_neg_integer() | nil} | nil
  def batch_by_l2_block_number(block_number, options \\ []) do
    select_repo(options).one(
      from(
        b in Batch,
        where: fragment("int8range(?, ?) <@ l2_block_range", ^block_number, ^(block_number + 1)),
        select: {b.number, b.bundle_id}
      )
    )
  end

  @doc """
    Gets last known L1 batch item from the `scroll_batches` table.

    ## Returns
    - A tuple `{block_number, transaction_hash}` - the block number and L1 transaction hash bound to the batch.
    - If the batch is not found, returns `{0, nil}`.
  """
  @spec last_l1_batch_item() :: {non_neg_integer(), binary() | nil}
  def last_l1_batch_item do
    query =
      from(b in Batch,
        select: {b.commit_block_number, b.commit_transaction_hash},
        order_by: [desc: b.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  @doc """
    Gets `final_batch_number` from the last known L1 bundle.

    ## Returns
    - The `final_batch_number` of the last L1 bundle.
    - If there are no bundles, returns -1.
  """
  @spec last_final_batch_number() :: integer()
  def last_final_batch_number do
    query =
      from(bb in BatchBundle,
        select: bb.final_batch_number,
        order_by: [desc: bb.id],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(-1)
  end

  @doc """
    Gets the last known L1 bridge item (deposit) from the `scroll_bridge` table.

    ## Returns
    - A tuple `{block_number, transaction_hash}` - the block number and L1 transaction hash bound to the deposit.
    - If the deposit is not found, returns `{0, nil}`.
  """
  @spec last_l1_bridge_item() :: {non_neg_integer(), binary() | nil}
  def last_l1_bridge_item do
    query =
      from(b in Bridge,
        select: {b.block_number, b.l1_transaction_hash},
        where: b.type == :deposit and not is_nil(b.block_number),
        order_by: [desc: b.index],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  @doc """
    Gets the last known L2 bridge item (withdrawal) from the `scroll_bridge` table.

    ## Returns
    - A tuple `{block_number, transaction_hash}` - the block number and L2 transaction hash bound to the withdrawal.
    - If the withdrawal is not found, returns `{0, nil}`.
  """
  @spec last_l2_bridge_item() :: {non_neg_integer(), binary() | nil}
  def last_l2_bridge_item do
    query =
      from(b in Bridge,
        select: {b.block_number, b.l2_transaction_hash},
        where: b.type == :withdrawal and not is_nil(b.block_number),
        order_by: [desc: b.index],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  @doc """
    Gets a value of the specified L1 Fee parameter for the given transaction from database.
    If a parameter is not defined for the transaction block number and index, the function returns `nil`.

    ## Parameters
    - `name`: A name of the parameter.
    - `transaction`: Transaction structure containing block number and transaction index within the block.
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - The parameter value, or `nil` if not defined.
  """
  @spec get_l1_fee_param_for_transaction(
          :overhead | :scalar | :commit_scalar | :blob_scalar | :l1_base_fee | :l1_blob_base_fee,
          Transaction.t(),
          api?: boolean()
        ) :: non_neg_integer() | nil
  @spec get_l1_fee_param_for_transaction(
          :overhead | :scalar | :commit_scalar | :blob_scalar | :l1_base_fee | :l1_blob_base_fee,
          Transaction.t()
        ) :: non_neg_integer() | nil
  def get_l1_fee_param_for_transaction(name, transaction, options \\ [])

  def get_l1_fee_param_for_transaction(_name, %{block_number: 0, index: 0}, _options), do: nil

  # credo:disable-for-next-line /Complexity/
  def get_l1_fee_param_for_transaction(name, transaction, options)
      when name in [:overhead, :scalar, :commit_scalar, :blob_scalar, :l1_base_fee, :l1_blob_base_fee] do
    base_query =
      L1FeeParam
      |> select([p], p.value)
      |> order_by([p], desc: p.block_number, desc: p.transaction_index)
      |> limit(1)

    query =
      cond do
        transaction.block_number == 0 ->
          # transaction.index is greater than 0 here
          where(base_query, [p], p.name == ^name and p.block_number == 0 and p.transaction_index < ^transaction.index)

        transaction.index == 0 ->
          # transaction.block_number is greater than 0 here
          where(base_query, [p], p.name == ^name and p.block_number < ^transaction.block_number)

        true ->
          where(
            base_query,
            [p],
            p.name == ^name and
              (p.block_number < ^transaction.block_number or
                 (p.block_number == ^transaction.block_number and p.transaction_index < ^transaction.index))
          )
      end

    select_repo(options).one(query)
  end

  @doc """
    Retrieves a list of Scroll deposits (both completed and unclaimed)
    sorted in descending order of the index.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database and paging options.

    ## Returns
    - A list of deposits.
  """
  @spec deposits(paging_options: PagingOptions.t(), api?: boolean()) :: [Bridge.t()]
  @spec deposits() :: [Bridge.t()]
  def deposits(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(
            b in Bridge,
            where: b.type == :deposit and not is_nil(b.l1_transaction_hash),
            order_by: [desc: b.index]
          )

        base_query
        |> page_deposits_or_withdrawals(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  @doc """
    Returns a total number of Scroll deposits (both completed and unclaimed).
  """
  @spec deposits_count(api?: boolean()) :: non_neg_integer() | nil
  @spec deposits_count() :: non_neg_integer() | nil
  def deposits_count(options \\ []) do
    query =
      from(
        b in Bridge,
        where: b.type == :deposit and not is_nil(b.l1_transaction_hash)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @doc """
    Retrieves a list of Scroll withdrawals (both completed and unclaimed)
    sorted in descending order of the index.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - A list of withdrawals.
  """
  @spec withdrawals(paging_options: PagingOptions.t(), api?: boolean()) :: [Bridge.t()]
  @spec withdrawals() :: [Bridge.t()]
  def withdrawals(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(
            b in Bridge,
            where: b.type == :withdrawal and not is_nil(b.l2_transaction_hash),
            order_by: [desc: b.index]
          )

        base_query
        |> page_deposits_or_withdrawals(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  @doc """
    Returns a total number of Scroll withdrawals (both completed and unclaimed).
  """
  @spec withdrawals_count(api?: boolean()) :: non_neg_integer() | nil
  @spec withdrawals_count() :: non_neg_integer() | nil
  def withdrawals_count(options \\ []) do
    query =
      from(
        b in Bridge,
        where: b.type == :withdrawal and not is_nil(b.l2_transaction_hash)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  defp page_batches(query, %PagingOptions{key: nil}), do: query

  defp page_batches(query, %PagingOptions{key: {number}}) do
    from(b in query, where: b.number < ^number)
  end

  defp page_batch_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_batch_blocks(query, %PagingOptions{key: {0}}), do: query

  defp page_batch_blocks(query, %PagingOptions{key: {block_number}}) do
    from(b in query, where: b.number < ^block_number)
  end

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: nil}), do: query

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: {index}}) do
    from(b in query, where: b.index < ^index)
  end

  @doc """
    Gets information about the latest committed batch and calculates average time between committed batches, in seconds.

    ## Parameters
      - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - If at least two batches exist:
      `{:ok, %{latest_batch_number: integer, latest_batch_timestamp: DateTime.t(), average_batch_time: integer}}`
      where:
        * latest_batch_number - number of the latest batch in the database.
        * latest_batch_timestamp - when the latest batch was committed to L1.
        * average_batch_time - average number of seconds between batches for the last 100 batches.

    - If less than two batches exist: `{:error, :not_found}`.
  """
  @spec get_latest_batch_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_batch_info(options \\ []) do
    query =
      from(b in Batch,
        order_by: [desc: b.number],
        limit: 100,
        select: %{
          number: b.number,
          timestamp: b.commit_timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_batch_metric(items)
  end
end
