import Config

alias EthereumJSONRPC.Variant

config :ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator, wait_per_timeout: 2

variant = Variant.get()

Code.require_file("#{variant}.exs", "#{__DIR__}/../../../explorer/config/test")
Code.require_file("#{variant}.exs", "#{__DIR__}/../../../indexer/config/test")
