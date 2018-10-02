defmodule Mix.Tasks.RestoreUserDataFromDump do
  use Mix.Task

  @shortdoc "restore user data from sql dump"
  def run(_) do
    {_, 0} =
      System.cmd("psql", [
        "-d",
        Application.get_env(:explorer, Explorer.Repo)[:database],
        "-a",
        "-f",
        "user_data_dump.sql"
      ])
  end
end
