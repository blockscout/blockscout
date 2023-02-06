defmodule Explorer.Celo.Telemetry.Instrumentation.Database do
  @moduledoc "Metrics for non app specific database stats"

  alias Explorer.Celo.Telemetry.Instrumentation
  use Instrumentation

  def metrics do
    # currently referencing indexer + `_current` suffix for backwards compatibility, this should be removed after
    # new dashboards are made that reference the new metric names
    [
      last_value("indexer_db_deadlocks_current",
        event_name: [:blockscout, :db, :deadlocks],
        measurement: :value,
        description: "Number of deadlocks on the db as reported by pg_stat_database (cumulative)"
      ),
      last_value("indexer_db_locks_current",
        event_name: [:blockscout, :db, :locks],
        measurement: :value,
        description: "Number of locks held on relations in the current database"
      ),
      last_value("indexer_db_longest_query_duration_current",
        event_name: [:blockscout, :db, :longest_query_duration],
        measurement: :value,
        description: "Age of longest running query"
      ),
      last_value("indexer_db_connections_count",
        event_name: [:blockscout, :db, :connections],
        measurement: :count,
        tags: [:app],
        description: "Connections to the current database by app name"
      ),
      last_value("db_deadlocks_current",
        event_name: [:blockscout, :db, :deadlocks],
        measurement: :value,
        description: "Number of deadlocks on the db as reported by pg_stat_database (cumulative)"
      ),
      last_value("db_locks_current",
        event_name: [:blockscout, :db, :locks],
        measurement: :value,
        description: "Number of locks held on relations in the current database"
      ),
      last_value("db_longest_query_duration_current",
        event_name: [:blockscout, :db, :longest_query_duration],
        measurement: :value,
        description: "Age of longest running query"
      ),
      last_value("db_connections_count",
        event_name: [:blockscout, :db, :connections],
        measurement: :count,
        tags: [:app],
        description: "Connections to the current database by app name"
      ),
      last_value("db_table_size_current",
        event_name: [:blockscout, :db, :table_size],
        measurement: :size,
        tags: [:name],
        description: "Largest tables by size in bytes"
      )
    ]
  end
end
