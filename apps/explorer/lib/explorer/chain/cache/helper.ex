defmodule Explorer.Chain.Cache.Helper do
  @moduledoc """
  Common helper functions for cache modules
  """
  alias Explorer.Repo

  def estimated_count_from(table_name) do
    %Postgrex.Result{rows: [[count]]} =
      Repo.query!("SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname = '#{table_name}';")

    count
  end
end
