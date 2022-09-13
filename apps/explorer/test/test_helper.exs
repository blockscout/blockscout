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

Mox.defmock(Explorer.ExchangeRates.Source.TestSource, for: Explorer.ExchangeRates.Source)
Mox.defmock(Explorer.KnownTokens.Source.TestSource, for: Explorer.KnownTokens.Source)
Mox.defmock(Explorer.Market.History.Source.TestSource, for: Explorer.Market.History.Source)
Mox.defmock(Explorer.History.TestHistorian, for: Explorer.History.Historian)

Mox.defmock(EthereumJSONRPC.Mox, for: EthereumJSONRPC.Transport)
