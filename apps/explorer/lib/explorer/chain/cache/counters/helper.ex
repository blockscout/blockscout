defmodule Explorer.Chain.Cache.Counters.Helper do
  @moduledoc """
    A helper for caching modules
  """

  alias Explorer.Chain
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter

  @block_number_threshold_1 10_000
  @block_number_threshold_2 50_000
  @block_number_threshold_3 150_000

  @ets_opts [
    :set,
    :named_table,
    :public,
    read_concurrency: true
  ]

  @doc """
    Returns the current time in milliseconds since the Unix epoch.

    This function retrieves the current UTC time and converts it to Unix
    timestamp in milliseconds.

    ## Returns
    - The number of milliseconds since the Unix epoch.
  """
  @spec current_time() :: non_neg_integer()
  def current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end

  @doc """
    Fetches a value from the ETS cache.

    This function fetches a value from the ETS cache by looking up the key in the
    specified cache table. If the key is found, it returns the value. Otherwise, it
    returns the default value.

    ## Parameters
    - `cache_name`: The name of the cache table to fetch from.
    - `key`: The key to fetch from the cache.
    - `default`: The default value to return if the key is not found.

    ## Returns
    - The value associated with the key in the cache table or the default value.
  """
  @spec fetch_from_ets_cache(atom(), binary() | atom() | tuple(), any()) :: any()
  def fetch_from_ets_cache(cache_name, key, default \\ nil) do
    case :ets.lookup(cache_name, key) do
      [{_, value}] ->
        value

      [] ->
        default
    end
  end

  @doc """
  Inserts a key-value pair into an ETS (Erlang Term Storage) cache.

  ## Parameters

    - `cache_name`: The name of the ETS table.
    - `key`: The key to insert into the cache.
    - `value`: The value associated with the key.

  ## Examples

      iex> put_into_ets_cache(:my_cache, :some_key, "some_value")
      true

  """
  @spec put_into_ets_cache(atom(), binary() | atom() | tuple(), any()) :: any()
  def put_into_ets_cache(cache_name, key, value) do
    :ets.insert(cache_name, {key, value})
  end

  @doc """
  Creates a new ETS (Erlang Term Storage) table with the given `cache_name` if it does not already exist.

  ## Parameters
    - cache_name: The name of the cache table to be created.

  ## Returns
    - The table identifier if the table is created.
    - `nil` if the table already exists.
  """
  @spec create_cache_table(atom()) :: any()
  def create_cache_table(cache_name) do
    if :ets.whereis(cache_name) == :undefined do
      :ets.new(cache_name, @ets_opts)
    end
  end

  @doc """
    Evaluates the count of a given cache key.

    This function evaluates the count of a given cache key by checking if the
    cached value from ETS is `nil`. If the cached value is `nil`, it fetches the
    value from the database and returns the estimated count. Otherwise, it returns
    the cached value from ETS.

    ## Parameters
    - `cache_key`: The key of the cache to evaluate.
    - `cached_value_from_ets`: The cached value from ETS.
    - `estimated_count`: The estimated count of the cache key.

    ## Returns
    - The evaluated count of the cache key.
  """
  @spec evaluate_count(binary(), non_neg_integer() | nil, non_neg_integer()) :: non_neg_integer()
  def evaluate_count(cache_key, nil, estimated_count) do
    cached_value_from_db =
      cache_key
      |> LastFetchedCounter.get()
      |> case do
        nil -> 0
        value -> Decimal.to_integer(value)
      end

    if cached_value_from_db === 0 do
      estimated_count
    else
      cached_value_from_db
    end
  end

  def evaluate_count(_cache_key, cached_value_from_ets, _estimated_count) when not is_nil(cached_value_from_ets) do
    cached_value_from_ets
  end

  @doc """
    Estimates the row count of a given table using PostgreSQL system catalogs.

    This function executes a query to estimate the number of rows in the specified
    table based on the table's reltuples and relpages values from the pg_class catalog.
    It provides a fast estimation rather than an exact count.

    ## Parameters
    - `table_name`: The name of the table to estimate the row count for.
    - `options`: An optional keyword list of options, such as selecting a specific repository.

    ## Returns
    - An estimated count of rows in the specified table or `nil` if the estimation is not available.
  """
  @spec estimated_count_from(binary(), keyword()) :: non_neg_integer() | nil
  @spec estimated_count_from(binary()) :: non_neg_integer() | nil
  def estimated_count_from(table_name, options \\ []) do
    %Postgrex.Result{rows: [[count]]} =
      Chain.select_repo(options).query!(
        "SELECT (CASE WHEN c.reltuples < 0 THEN NULL WHEN c.relpages = 0 THEN float8 '0' ELSE c.reltuples / c.relpages END * (pg_catalog.pg_relation_size(c.oid) / pg_catalog.current_setting('block_size')::int))::bigint FROM pg_catalog.pg_class c WHERE c.oid = '#{table_name}'::regclass"
      )

    count
  end

  @doc """
    Calculates the time-to-live (TTL) for a given module in the cache.

    ## Parameters

      * `module` - The module for which to calculate the TTL.
      * `management_variable` - The management environment variable.

    ## Returns

    The TTL for the module.

  """
  @spec ttl(atom, String.t()) :: non_neg_integer()
  def ttl(module, management_variable) do
    min_blockchain_block_number = Application.get_env(:indexer, :first_block)
    max_block_number = Chain.fetch_max_block_number()
    blocks_amount = max_block_number - min_blockchain_block_number
    global_ttl_from_var = Application.get_env(:explorer, module)[:global_ttl]

    cond do
      System.get_env(management_variable) not in ["", nil] -> global_ttl_from_var
      blocks_amount < @block_number_threshold_1 -> :timer.seconds(10)
      blocks_amount >= @block_number_threshold_1 and blocks_amount < @block_number_threshold_2 -> :timer.seconds(30)
      blocks_amount >= @block_number_threshold_2 and blocks_amount < @block_number_threshold_3 -> :timer.minutes(2)
      true -> global_ttl_from_var
    end
  end
end
