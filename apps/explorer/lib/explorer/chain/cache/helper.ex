defmodule Explorer.Chain.Cache.Helper do
  @moduledoc """
  Common helper functions for cache modules
  """
  alias Explorer.Chain

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
end
