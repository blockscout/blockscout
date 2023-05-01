defmodule Explorer.Chain.Cache.Helper do
  @moduledoc """
  Common helper functions for cache modules
  """
  alias Explorer.Chain

  def estimated_count_from(table_name, options \\ []) do
    %Postgrex.Result{rows: [[count]]} =
      Chain.select_repo(options).query!(
        "SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname = '#{table_name}';"
      )

    count
  end
end
