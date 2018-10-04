defmodule Mix.Tasks.RestoreUserDataFromDump do
  use Mix.Task

  @shortdoc "Restore user data from a sql dump"

  @moduledoc """
  Download dump file from an object storage and restore it to the app's database

  no command line options supported
  """

  alias Explorer.Backup.UserDataDump

  @doc false
  def run(_) do
    Application.ensure_all_started(:explorer)
    UserDataDump.download_and_restore_dump()
  end
end
