use Mix.Config

config :explorer, Explorer.Scheduler,
  enabled: System.get_env("ENABLE_SCHEDULER") || false,
  jobs: [{"0 0,12 * * *", {Explorer.Backup.UserDataDump, :generate_and_upload_dump, []}}]
