import Config

config :indexer, Indexer.Prometheus.MetricsCron, metrics_fetcher_blocks_count: 1000
config :indexer, Indexer.Prometheus.MetricsCron, metrics_cron_interval: System.get_env("METRICS_CRON_INTERVAL") || "2"

config :indexer, :telemetry_config, [
  [
    name: [:blockscout, :ingested],
    type: :summary,
    label: "indexer_import_ingested",
    meta: %{
      help: "Blockchain primitives ingested via `Import.all` by type",
      metric_labels: [:type],
      function: &Indexer.Celo.Telemetry.Helper.filter_imports/1
    }
  ],
  [
    name: [:blockscout, :chain_event_send],
    type: :counter,
    label: "indexer_chain_events_sent",
    meta: %{
      help: "Number of chain events sent via pubsub"
    }
  ]
]

config :prometheus, Indexer.Prometheus.Exporter,
  path: "/metrics/indexer",
  format: :text,
  registry: :default
