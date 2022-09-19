import Config

alias EthereumJSONRPC.Variant

config :explorer, Explorer.ExchangeRates, enabled: false, store: :none

config :explorer, Explorer.KnownTokens, enabled: false, store: :none

config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
  domain: "example.com",
  client_id: "clien_id",
  client_secret: "secrets"

config :ueberauth, Ueberauth,
  logout_url: "example.com/logout",
  logout_return_to_url: "example.com/return"

variant = Variant.get()

Code.require_file("#{variant}.exs", "#{__DIR__}/../../../explorer/config/test")
Code.require_file("#{variant}.exs", "#{__DIR__}/../../../indexer/config/test")
