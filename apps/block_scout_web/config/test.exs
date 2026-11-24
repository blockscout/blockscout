# SPDX-License-Identifier: LicenseRef-Blockscout
import Config

config :block_scout_web, :sql_sandbox, true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :block_scout_web, BlockScoutWeb.Endpoint,
  http: [port: 4002],
  secret_key_base: "27Swe6KtEtmN37WyEYRjKWyxYULNtrxlkCEKur4qoV+Lwtk8lafsR16ifz1XBBYj",
  server: true,
  pubsub_server: BlockScoutWeb.PubSub,
  checksum_address_hashes: true

config :block_scout_web, BlockScoutWeb.Tracer, disabled?: false

config :logger, :block_scout_web, path: Path.absname("logs/test/block_scout_web.log")

# Configure Fluffy: browser requests carry the test's sandbox metadata for
# these repos. Traces and screenshots of failed tests go to test-results/.
config :fluffy, endpoint: BlockScoutWeb.Endpoint, ecto_repos: [Explorer.Repo]

config :playwright, :test,
  browser_name: :chromium,
  viewport: %{width: 1200, height: 800},
  action_timeout: 15_000,
  navigation_timeout: 15_000,
  trace: :retain_on_failure,
  screenshot: :only_on_failure

config :block_scout_web, BlockScoutWeb.Counters.BlocksIndexedCounter, enabled: false

config :block_scout_web, BlockScoutWeb.Counters.InternalTransactionsIndexedCounter, enabled: false

config :oauth2, adapter: Explorer.Mock.TeslaAdapter

config :tesla, adapter: Explorer.Mock.TeslaAdapter

config :ueberauth, Ueberauth,
  providers: [
    auth0: {
      Ueberauth.Strategy.Auth0,
      [callback_url: "example.com/callback"]
    }
  ]
