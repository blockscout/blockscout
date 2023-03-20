Application.ensure_all_started(:mox)
Mox.defmock(EventStream.Publisher.Mock, for: EventStream.Publisher)

junit_folder = Mix.Project.build_path() <> "/junit/#{Mix.Project.config()[:app]}"
File.mkdir_p!(junit_folder)
:ok = Application.put_env(:junit_formatter, :report_dir, junit_folder)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])

ExUnit.start()
