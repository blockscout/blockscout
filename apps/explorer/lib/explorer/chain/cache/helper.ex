defmodule Explorer.Chain.Cache.Helper do
  @moduledoc """
  Common helper functions for cache modules
  """
  alias Explorer.Repo

  def estimated_count_from(table_name) do
    %Postgrex.Result{rows: [[count]]} =
      Repo.query!(
        "SELECT (CASE WHEN c.reltuples < 0 THEN NULL WHEN c.relpages = 0 THEN float8 '0' ELSE c.reltuples / c.relpages END * (pg_catalog.pg_relation_size(c.oid) / pg_catalog.current_setting('block_size')::int))::bigint FROM pg_catalog.pg_class c WHERE c.oid = '#{table_name}'::regclass"
      )

    count
  end
end
