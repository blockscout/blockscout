# https://github.com/CircleCI-Public/circleci-demo-elixir-phoenix/blob/a89de33a01df67b6773ac90adc74c34367a4a2d6/test/test_helper.exs#L1-L3
junit_folder = Mix.Project.build_path() <> "/junit/#{Mix.Project.config()[:app]}"
File.mkdir_p!(junit_folder)
:ok = Application.put_env(:junit_formatter, :report_dir, junit_folder)

# Counter `test --no-start`.  `--no-start` is needed for `:indexer` compatibility
{:ok, _} = Application.ensure_all_started(:block_scout_web)

{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, BlockScoutWeb.Endpoint.url())

{:ok, _} = Application.ensure_all_started(:ex_machina)

# Bureaucrat.start(
#   writer: Bureaucrat.ApiBlueprintWriter,
#   default_path: "API blueprint.md",
#   env_var: "DOC"
# )

Bureaucrat.start()

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter, Bureaucrat.Formatter])
ExUnit.start()

Mox.defmock(Explorer.ExchangeRates.Source.TestSource, for: Explorer.ExchangeRates.Source)

Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Account, :manual)

Absinthe.Test.prime(BlockScoutWeb.Schema)

Mox.defmock(EthereumJSONRPC.Mox, for: EthereumJSONRPC.Transport)

Mox.defmock(BlockScoutWeb.TestCaptchaHelper, for: BlockScoutWeb.CaptchaHelper)
