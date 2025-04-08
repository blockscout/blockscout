import Config

alias EthereumJSONRPC.Variant

config :ethereum_jsonrpc, EthereumJSONRPC.Utility.EndpointAvailabilityChecker, enabled: false
config :explorer, Explorer.Market.Fetcher.Coin, enabled: false, store: :ets

config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: "example.com",
  client_id: "client_id",
  client_secret: "secrets"

config :ueberauth, Ueberauth, logout_url: "example.com/logout"

variant = Variant.get()

Code.require_file("#{variant}.exs", "#{__DIR__}/../../../explorer/config/test")
Code.require_file("#{variant}.exs", "#{__DIR__}/../../../indexer/config/test")
