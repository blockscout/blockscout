# https://github.com/CircleCI-Public/circleci-demo-elixir-phoenix/blob/a89de33a01df67b6773ac90adc74c34367a4a2d6/test/test_helper.exs#L1-L3
junit_folder = Mix.Project.build_path() <> "/junit/#{Mix.Project.config()[:app]}"
File.mkdir_p!(junit_folder)
:ok = Application.put_env(:junit_formatter, :report_dir, junit_folder)

# Counter `test --no-start`.  `--no-start` is needed for `:indexer` compatibility
{:ok, _} = Application.ensure_all_started(:ethereum_jsonrpc)

Mox.defmock(EthereumJSONRPC.Mox, for: EthereumJSONRPC.Transport)
# for when we need to simulate HTTP-specific stuff like 413 Request Entity Too Large
Mox.defmock(EthereumJSONRPC.HTTP.Mox, for: EthereumJSONRPC.HTTP)
# for when we need to simulate WebSocket-specific stuff
Mox.defmock(EthereumJSONRPC.WebSocket.Mox, for: EthereumJSONRPC.WebSocket)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()
