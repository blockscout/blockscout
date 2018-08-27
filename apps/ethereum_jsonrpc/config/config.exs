use Mix.Config

config :logger, :ethereum_jsonrpc,
  # keep synced with `config/config.exs`
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  metadata_filter: [application: :ethereum_jsonrpc]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
