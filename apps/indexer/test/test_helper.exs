# https://github.com/CircleCI-Public/circleci-demo-elixir-phoenix/blob/a89de33a01df67b6773ac90adc74c34367a4a2d6/test/test_helper.exs#L1-L3
junit_folder = Mix.Project.build_path() <> "/junit/#{Mix.Project.config()[:app]}"
File.mkdir_p!(junit_folder)
:ok = Application.put_env(:junit_formatter, :report_dir, junit_folder)

# start all dependencies, but not Indexer itself as we need to unit test the supervision tree without and don't want the
# genesis task scanning in the background
Application.load(:indexer)

for application <- Application.spec(:indexer, :applications) do
  Application.ensure_all_started(application)
end

# no declared in :applications since it is test-only
{:ok, _} = Application.ensure_all_started(:ex_machina)

Mox.defmock(EthereumJSONRPC.Mox, for: EthereumJSONRPC.Transport)
Mox.defmock(Indexer.BufferedTaskTest.RetryableTask, for: Indexer.BufferedTask)
Mox.defmock(Indexer.BufferedTaskTest.ShrinkableTask, for: Indexer.BufferedTask)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, :auto)
