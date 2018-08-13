use Mix.Config

config :explorer_web, :sql_sandbox, true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :explorer_web, ExplorerWeb.Endpoint,
  http: [port: 4001],
  secret_key_base: "27Swe6KtEtmN37WyEYRjKWyxYULNtrxlkCEKur4qoV+Lwtk8lafsR16ifz1XBBYj",
  server: true

# Configure wallaby
config :wallaby,
  driver: Wallaby.Experimental.Chrome,
  screenshot_on_failure: true

config :explorer_web, :fake_adapter, ExplorerWeb.FakeAdapter
