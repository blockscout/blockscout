defmodule Mix.Tasks.DumpUserData do
  use Mix.Task

  @user_tables [Explorer.Chain.Address.Name, Explorer.Chain.SmartContract]

  @shortdoc "generate dump of data from tables that require manual input"
  def run(_) do
    {dump, _} =
      System.cmd(
        "pg_dump",
        Enum.reduce(@user_tables, [Application.get_env(:explorer, Explorer.Repo)[:database], "-a"], fn schema, acc ->
          Enum.concat(acc, ["-t", schema.__schema__(:source)])
        end)
      )

    File.write!("user_data_dump.sql", dump)
  end
end
