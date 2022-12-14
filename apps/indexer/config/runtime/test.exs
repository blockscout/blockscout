import Config

alias EthereumJSONRPC.Variant

variant = Variant.get()

config :indexer,
  block_transformer: Indexer.Transform.Blocks.Base

Code.require_file("#{variant}.exs", "#{__DIR__}/../../../explorer/config/test")
Code.require_file("#{variant}.exs", "#{__DIR__}/../../../indexer/config/test")
