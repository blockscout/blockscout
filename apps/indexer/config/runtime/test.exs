import Config

alias EthereumJSONRPC.Variant

config :indexer, Indexer.Fetcher.Beacon.Blob.Supervisor, disabled?: true
config :indexer, Indexer.Fetcher.Beacon.Blob, start_block: 0
config :indexer, Indexer.Fetcher.OnDemand.CoinBalance.Supervisor, disabled?: true
config :indexer, Indexer.Fetcher.OnDemand.TokenBalance.Supervisor, disabled?: true

variant = Variant.get()

Code.require_file("#{variant}.exs", "#{__DIR__}/../../../explorer/config/test")
Code.require_file("#{variant}.exs", "#{__DIR__}/../../../indexer/config/test")
