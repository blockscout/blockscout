import Config

config :block_scout_web, :sql_sandbox, true

network_path =
  "NETWORK_PATH"
  |> System.get_env("/")
  |> (&(if !String.ends_with?(&1, "/") do
          &1 <> "/"
        else
          &1
        end)).()

api_path =
  "API_PATH"
  |> System.get_env("/")
  |> (&(if !String.ends_with?(&1, "/") do
          &1 <> "/"
        else
          &1
        end)).()

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :block_scout_web, BlockScoutWeb.Endpoint,
  url: [
    path: network_path,
    api_path: api_path
  ],
  http: [port: 4002],
  secret_key_base: "27Swe6KtEtmN37WyEYRjKWyxYULNtrxlkCEKur4qoV+Lwtk8lafsR16ifz1XBBYj",
  server: true,
  pubsub_server: BlockScoutWeb.PubSub,
  checksum_address_hashes: true

config :block_scout_web, BlockScoutWeb.Tracer, disabled?: false

config :logger, :block_scout_web,
  level: :warn,
  path: Path.absname("logs/test/block_scout_web.log")

# Configure wallaby
config :wallaby, screenshot_on_failure: true, driver: Wallaby.Chrome, js_errors: false

config :block_scout_web, BlockScoutWeb.Counters.BlocksIndexedCounter, enabled: false

config :block_scout_web, :captcha_helper, BlockScoutWeb.TestCaptchaHelper

config :ueberauth, Ueberauth,
  providers: [
    auth0: {
      Ueberauth.Strategy.Auth0,
      [callback_url: "example.com/callback"]
    }
  ]
