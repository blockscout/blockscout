use Mix.Config

config :logger, :indexer,
  level: :warn,
  path: Path.absname("logs/test/indexer.log")
