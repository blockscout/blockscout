defmodule Explorer.Chain.PolygonZkevm.Reader do
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

  alias Explorer.Chain.PolygonZkevm.{BatchTransaction, Bridge, BridgeL1Token, LifecycleTransaction, TransactionBatch}
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Prometheus.Instrumenter
  alias Indexer.Helper

  @doc """
    Reads a batch by its number from database.
    If the number is :latest, gets the latest batch from `polygon_zkevm_transaction_batches` table.
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
    Reads a list of batches from `polygon_zkevm_transaction_batches` table.
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
    Reads a list of L2 transaction hashes from `polygon_zkevm_batch_l2_transactions` table.
  """
  @spec batch_transactions(non_neg_integer(), list()) :: list()
  def batch_transactions(batch_number, options \\ []) do
    query = from(bts in BatchTransaction, where: bts.batch_number == ^batch_number)

    select_repo(options).all(query)
  end

  @doc """
    Tries to read L1 token data (address, symbol, decimals) for the given addresses
    from the database. If the data for an address is not found in Explorer.Chain.PolygonZkevm.BridgeL1Token,
    the address is returned in the list inside the tuple (the second item of the tuple).
    The first item of the returned tuple contains `L1 token address -> L1 token data` map.
  """
  @spec get_token_data_from_db(list()) :: {map(), list()}
  def get_token_data_from_db(token_addresses) do
    # try to read token symbols and decimals from the database
    query =
      from(
        t in BridgeL1Token,
        where: t.address in ^token_addresses,
        select: {t.address, t.decimals, t.symbol}
      )

    token_data =
      query
      |> Repo.all()
      |> Enum.reduce(%{}, fn {address, decimals, symbol}, acc ->
        token_address = Helper.address_hash_to_string(address, true)
        Map.put(acc, token_address, %{symbol: symbol, decimals: decimals})
      end)

    token_addresses_for_rpc =
      token_addresses
      |> Enum.reject(fn address ->
        Map.has_key?(token_data, Helper.address_hash_to_string(address, true))
      end)

    {token_data, token_addresses_for_rpc}
  end

  @doc """
    Gets last known L1 item (deposit) from polygon_zkevm_bridge table.
    Returns block number and L1 transaction hash bound to that deposit.
    If not found, returns zero block number and nil as the transaction hash.
  """
  @spec last_l1_item() :: {non_neg_integer(), binary() | nil}
  def last_l1_item do
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
    Gets last known L2 item (withdrawal) from polygon_zkevm_bridge table.
    Returns block number and L2 transaction hash bound to that withdrawal.
    If not found, returns zero block number and nil as the transaction hash.
  """
  @spec last_l2_item() :: {non_neg_integer(), binary() | nil}
  def last_l2_item do
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
    Gets the number of the latest batch with defined verify_id from `polygon_zkevm_transaction_batches` table.
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
    Reads a list of L1 transactions by their hashes from `polygon_zkevm_lifecycle_l1_transactions` table.
  """
  @spec lifecycle_transactions(list()) :: list()
  def lifecycle_transactions([]), do: []

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
    Determines ID of the future lifecycle transaction by reading `polygon_zkevm_lifecycle_l1_transactions` table.
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

  @doc """
    Builds `L1 token address -> L1 token id` map for the given token addresses.
    The info is taken from Explorer.Chain.PolygonZkevm.BridgeL1Token.
    If an address is not in the table, it won't be in the resulting map.
  """
  @spec token_addresses_to_ids_from_db(list()) :: map()
  def token_addresses_to_ids_from_db(addresses) do
    query = from(t in BridgeL1Token, select: {t.address, t.id}, where: t.address in ^addresses)

    query
    |> Repo.all(timeout: :infinity)
    |> Enum.reduce(%{}, fn {address, id}, acc ->
      Map.put(acc, Helper.address_hash_to_string(address), id)
    end)
  end

  @doc """
    Retrieves a list of Polygon zkEVM deposits (completed and unclaimed)
    sorted in descending order of the index.
  """
  @spec deposits(list()) :: list()
  def deposits(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(
            b in Bridge,
            left_join: t1 in assoc(b, :l1_token),
            left_join: t2 in assoc(b, :l2_token),
            where: b.type == :deposit and not is_nil(b.l1_transaction_hash),
            preload: [l1_token: t1, l2_token: t2],
            order_by: [desc: b.index]
          )

        base_query
        |> page_deposits_or_withdrawals(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  @doc """
    Returns a total number of Polygon zkEVM deposits (completed and unclaimed).
  """
  @spec deposits_count(list()) :: term() | nil
  def deposits_count(options \\ []) do
    query =
      from(
        b in Bridge,
        where: b.type == :deposit and not is_nil(b.l1_transaction_hash)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @doc """
    Retrieves a list of Polygon zkEVM withdrawals (completed and unclaimed)
    sorted in descending order of the index.
  """
  @spec withdrawals(list()) :: list()
  def withdrawals(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(
            b in Bridge,
            left_join: t1 in assoc(b, :l1_token),
            left_join: t2 in assoc(b, :l2_token),
            where: b.type == :withdrawal and not is_nil(b.l2_transaction_hash),
            preload: [l1_token: t1, l2_token: t2],
            order_by: [desc: b.index]
          )

        base_query
        |> page_deposits_or_withdrawals(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  @doc """
    Returns a total number of Polygon zkEVM withdrawals (completed and unclaimed).
  """
  @spec withdrawals_count(list()) :: term() | nil
  def withdrawals_count(options \\ []) do
    query =
      from(
        b in Bridge,
        where: b.type == :withdrawal and not is_nil(b.l2_transaction_hash)
      )

    select_repo(options).aggregate(query, :count, timeout: :infinity)
  end

  @doc """
    Filters token decimals value (cannot be greater than 0xFF).
  """
  @spec sanitize_decimals(non_neg_integer()) :: non_neg_integer()
  def sanitize_decimals(decimals) do
    if decimals > 0xFF do
      0
    else
      decimals
    end
  end

  @doc """
    Filters token symbol (cannot be longer than 16 characters).
  """
  @spec sanitize_symbol(String.t()) :: String.t()
  def sanitize_symbol(symbol) do
    String.slice(symbol, 0, 16)
  end

  defp page_batches(query, %PagingOptions{key: nil}), do: query

  defp page_batches(query, %PagingOptions{key: {number}}) do
    from(tb in query, where: tb.number < ^number)
  end

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: nil}), do: query

  defp page_deposits_or_withdrawals(query, %PagingOptions{key: {index}}) do
    from(b in query, where: b.index < ^index)
  end

  @doc """
    Gets information about the latest finalized batch and calculates average time between finalized batches, in seconds.

    ## Parameters
      - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - If at least two batches exist:
      `{:ok, %{latest_batch_number: integer, latest_batch_timestamp: DateTime.t(), average_batch_time: integer}}`
      where:
        * latest_batch_number - id of the latest batch in the database.
        * latest_batch_timestamp - when the latest batch was committed to L1.
        * average_batch_time - average number of seconds between batches for the last 100 batches.

    - If less than two batches exist: `{:error, :not_found}`.
  """
  @spec get_latest_batch_info(keyword()) :: {:ok, map()} | {:error, :not_found}
  def get_latest_batch_info(options \\ []) do
    query =
      from(tb in TransactionBatch,
        where: not is_nil(tb.timestamp),
        order_by: [desc: tb.number],
        limit: 100,
        select: %{
          number: tb.number,
          timestamp: tb.timestamp
        }
      )

    items = select_repo(options).all(query)

    Instrumenter.prepare_batch_metric(items)
  end
end
