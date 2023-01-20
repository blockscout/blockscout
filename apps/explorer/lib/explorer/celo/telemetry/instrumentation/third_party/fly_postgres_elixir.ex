defmodule Explorer.Celo.Telemetry.Instrumentation.FlyPostgres do
  @moduledoc "Metrics for the fly_postgres_elixir library"

  alias Explorer.Celo.Telemetry.Instrumentation
  use Instrumentation

  def metrics do
    [
      counter("indexer_local_db_query",
        event_name: [:fly_postgres_elixir, :local_exec],
        measurement: :count,
        description: "DB queries this app executed against local db",
        tags: [:func]
      ),
      counter("indexer_remote_db_query",
        event_name: [:fly_postgres_elixir, :primary_exec],
        measurement: :count,
        description: "DB queries this app executed on primary via rpc",
        tags: [:func]
      ),
      counter("indexer_handled_rpc_query",
        event_name: [:fly_postgres_elixir, :remote_exec],
        measurement: :count,
        description: "DB queries this app has received via rpc for execution",
        tags: [:func]
      )
    ]
  end
end
