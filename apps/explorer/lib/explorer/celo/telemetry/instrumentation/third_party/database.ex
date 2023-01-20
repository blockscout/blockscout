defmodule Explorer.Celo.Telemetry.Instrumentation.Database do
  @moduledoc "Metrics for non app specific database stats"

  alias Explorer.Celo.Telemetry.Instrumentation
  use Instrumentation

  def metrics do
    # referencing indexer + `_current` suffix for backwards compatibility
    [
      last_value("indexer_db_deadlocks_current",
        event_name: [:indexer, :db, :deadlocks],
        measurement: :value,
        description: "Number of deadlocks on the db as reported by pg_stat_database (cumulative)"
      ),
      last_value("indexer_db_locks_current",
        event_name: [:indexer, :db, :locks],
        measurement: :value,
        description: "Number of locks held on relations in the current database"
      ),
      last_value("indexer_db_longest_query_duration_current",
        event_name: [:indexer, :db, :longest_query_duration],
        measurement: :value,
        description: "Age of longest running query"
      ),
      last_value("indexer_db_connections_count",
        event_name: [:blockscout, :db, :connections],
        measurement: :count,
        tags: [:app],
        description: "Connections to the current database by app name"
      )
    ]
  end
end
