# https://github.com/CircleCI-Public/circleci-demo-elixir-phoenix/blob/a89de33a01df67b6773ac90adc74c34367a4a2d6/test/test_helper.exs#L1-L3
junit_folder = Mix.Project.build_path() <> "/junit/#{Mix.Project.config()[:app]}"
File.mkdir_p!(junit_folder)
:ok = Application.put_env(:junit_formatter, :report_dir, junit_folder)

# Counter `test --no-start`.  `--no-start` is needed for `:indexer` compatibility
{:ok, _} = Application.ensure_all_started(:explorer)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

{:ok, _} = Application.ensure_all_started(:ex_machina)

Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Account, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.PolygonEdge, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.PolygonZkevm, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.RSK, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Shibarium, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Suave, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Beacon, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.BridgedTokens, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Filecoin, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Stability, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Mud, :auto)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.ShrunkInternalTransactions, :auto)

Mox.defmock(Explorer.Market.Source.TestSource, for: Explorer.Market.Source)
Mox.defmock(Explorer.History.TestHistorian, for: Explorer.History.Historian)

Mox.defmock(EthereumJSONRPC.Mox, for: EthereumJSONRPC.Transport)

Mox.defmock(Explorer.Mock.TeslaAdapter, for: Tesla.Adapter)
