# https://github.com/CircleCI-Public/circleci-demo-elixir-phoenix/blob/a89de33a01df67b6773ac90adc74c34367a4a2d6/test/test_helper.exs#L1-L3
junit_folder = Mix.Project.build_path() <> "/junit/#{Mix.Project.config()[:app]}"
File.mkdir_p!(junit_folder)
:ok = Application.put_env(:junit_formatter, :report_dir, junit_folder)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()
