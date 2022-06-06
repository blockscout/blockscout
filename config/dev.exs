use Mix.Config

# DO NOT make it `:debug` or all Ecto logs will be shown for indexer
config :logger, :console, level: :info

config :logger, :ecto,
  level: :debug,
  path: Path.absname("logs/dev/ecto.log")

config :logger, :error, path: Path.absname("logs/dev/error.log")

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :dev,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: "development"
  },
  included_environments: [:dev]
