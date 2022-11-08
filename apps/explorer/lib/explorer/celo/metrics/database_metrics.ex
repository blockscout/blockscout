defmodule Explorer.Celo.Metrics.DatabaseMetrics do
  @moduledoc "Database metric queries"

  alias Ecto.Adapters.SQL
  alias Explorer.Repo.Local, as: Repo

  @spec fetch_number_of_locks :: non_neg_integer()
  def fetch_number_of_locks do
    result =
      SQL.query(Repo, """
      SELECT COUNT(*) FROM (SELECT blocked_locks.pid     AS blocked_pid,
           blocked_activity.usename  AS blocked_user,
           blocking_locks.pid     AS blocking_pid,
           blocking_activity.usename AS blocking_user,
           blocked_activity.query    AS blocked_statement,
           blocking_activity.query   AS current_statement_in_blocking_process
      FROM  pg_catalog.pg_locks         blocked_locks
      JOIN pg_catalog.pg_stat_activity blocked_activity  ON blocked_activity.pid = blocked_locks.pid
      JOIN pg_catalog.pg_locks         blocking_locks
          ON blocking_locks.locktype = blocked_locks.locktype
          AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
          AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
          AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
          AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
          AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
          AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
          AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
          AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
          AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
          AND blocking_locks.pid != blocked_locks.pid
      JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
      WHERE NOT blocked_locks.GRANTED) a;
      """)

    case result do
      {:ok, %Postgrex.Result{rows: [[rows]]}} -> rows
      _ -> 0
    end
  end

  @spec fetch_number_of_dead_locks :: non_neg_integer()
  def fetch_number_of_dead_locks do
    database =
      :explorer
      |> Application.get_env(Repo)
      |> Keyword.get(:database)

    result =
      SQL.query(
        Repo,
        """
        SELECT deadlocks FROM pg_stat_database where datname = $1;
        """,
        [database]
      )

    case result do
      {:ok, %Postgrex.Result{rows: [[rows]]}} -> rows
      _ -> 0
    end
  end

  @spec fetch_name_and_duration_of_longest_query :: non_neg_integer()
  def fetch_name_and_duration_of_longest_query do
    result =
      SQL.query(Repo, """
        SELECT query, NOW() - xact_start AS duration FROM pg_stat_activity
        WHERE state IN ('idle in transaction', 'active') ORDER BY now() - xact_start DESC LIMIT 1;
      """)

    {:ok, longest_query_map} = result

    case Map.fetch(longest_query_map, :rows) do
      {:ok, [[_, longest_query_duration]]} when not is_nil(longest_query_duration) -> longest_query_duration.secs
      _ -> 0
    end
  end
end
