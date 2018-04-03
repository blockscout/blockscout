use Mix.Config

# Do not print debug messages in production
config :logger, level: :info

# Configure New Relic
config :new_relixir,
  application_name: System.get_env("NEW_RELIC_APP_NAME"),
  license_key: System.get_env("NEW_RELIC_LICENSE_KEY"),
  active: true
