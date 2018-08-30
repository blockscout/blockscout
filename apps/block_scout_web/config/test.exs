use Mix.Config

config :block_scout_web, :sql_sandbox, true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :block_scout_web, BlockScoutWeb.Endpoint,
  http: [port: 4001],
  secret_key_base: "27Swe6KtEtmN37WyEYRjKWyxYULNtrxlkCEKur4qoV+Lwtk8lafsR16ifz1XBBYj",
  server: true

config :logger, :block_scout_web,
  level: :warn,
  path: Path.absname("logs/test/block_scout_web.log")

# Configure wallaby
config :wallaby, screenshot_on_failure: true

config :block_scout_web, :fake_adapter, BlockScoutWeb.FakeAdapter
