import Config

config :indexer, Indexer.Prometheus.MetricsCron, metrics_fetcher_blocks_count: 1000
config :indexer, Indexer.Prometheus.MetricsCron, metrics_cron_interval: System.get_env("METRICS_CRON_INTERVAL") || "2"

config :indexer, :telemetry_config, [
  [
    name: [:blockscout, :ingested],
    type: :summary,
    metric_id: "indexer_import_ingested",
    meta: %{
      help: "Blockchain primitives ingested via `Import.all` by type",
      metric_labels: [:type],
      function: &Indexer.Celo.Telemetry.Helper.filter_imports/2
    }
  ],
  [
    name: [:blockscout, :chain_event_send],
    type: :counter,
    metric_id: "indexer_chain_events_sent",
    meta: %{
      help: "Number of chain events sent via pubsub"
    }
  ],
  [
    name: [:fly_postgres_elixir, :local_exec],
    type: :summary,
    metric_id: "indexer_local_db_query",
    meta: %{
      metric_labels: [:func],
      help: "DB queries this app executed against local db",
      function: &Indexer.Celo.Telemetry.Helper.transform_db_call/2
    }
  ],
  [
    name: [:fly_postgres_elixir, :primary_exec],
    type: :summary,
    metric_id: "indexer_remote_db_query",
    meta: %{
      metric_labels: [:func],
      help: "DB queries this app executed on primary via rpc",
      function: &Indexer.Celo.Telemetry.Helper.transform_db_call/2
    }
  ],
  [
    name: [:fly_postgres_elixir, :remote_exec],
    type: :summary,
    metric_id: "indexer_handled_rpc_query",
    meta: %{
      metric_labels: [:func],
      help: "DB queries this app has received via rpc for execution",
      function: &Indexer.Celo.Telemetry.Helper.transform_db_call/2
    }
  ]
]

config :prometheus, Indexer.Prometheus.Exporter,
  path: "/metrics/indexer",
  format: :text,
  registry: :default
