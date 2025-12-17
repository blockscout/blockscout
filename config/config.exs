# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
for config <- "../apps/*/config/config.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  import_config config
end

config :phoenix, :json_library, Jason

config :logger, :default_formatter, format: "$dateT$time $metadata[$level] $message\n"

config :logger, :console, metadata: ConfigHelper.logger_metadata()

config :logger, :error, metadata: ConfigHelper.logger_metadata()

config :logger, :block_scout_web, metadata: ConfigHelper.logger_metadata()

# todo: migrate from deprecated usages
config :tesla, disable_deprecated_builder_warning: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
