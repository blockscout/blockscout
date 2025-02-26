defmodule Explorer.Chain.Cache.Helper do
  @moduledoc """
  Common helper functions for cache modules
  """
  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain

  @block_number_threshold_1 10_000
  @block_number_threshold_2 50_000
  @block_number_threshold_3 150_000

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
    min_blockchain_block_number =
      RangesHelper.get_min_block_number_from_range_string(Application.get_env(:indexer, :block_ranges))

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
