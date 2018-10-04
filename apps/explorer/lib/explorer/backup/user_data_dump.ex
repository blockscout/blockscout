defmodule Explorer.Backup.UserDataDump do
  @moduledoc """
  Run the process of creating and restoring dumps of user inserted data
  """

  alias Ecto.Adapters.SQL
  alias Explorer.Backup.Uploader
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Repo

  @user_table_names Enum.map([Address.Name, SmartContract], & &1.__schema__(:source))

  @doc """
  Generates and uploads the dumps for all tables listed on `@user_table_names`
  """
  def generate_and_upload_dump(upload_function \\ &Uploader.upload_file/1) do
    results =
      Enum.map(@user_table_names, fn table_name ->
        table_name
        |> generate_dump()
        |> upload_function.()
        |> delete_temp_file()
      end)

    {:ok, results}
  rescue
    e in [Postgrex.Error, File.Error, ExAws.Error] -> {:error, e}
  end

  @doc """
  Downloads and restores the dumps for all tables listed on `@user_table_names`
  """
  def download_and_restore_dump(download_function \\ &Uploader.download_file/1) do
    results =
      Enum.map(@user_table_names, fn table_name ->
        (table_name <> ".csv")
        |> download_function.()
        |> String.replace(".csv", "")
        |> restore_from_dump()
        |> delete_temp_file()
      end)

    {:ok, results}
  rescue
    e in [Postgrex.Error, File.Error, ExAws.Error] -> {:error, e}
  end

  @doc """
  Generate a dump of the data on user tables and write to a tempfile
  """
  # sobelow_skip ["SQL.Query", "Traversal"]
  def generate_dump(table_name) do
    response = SQL.query!(Repo, postgres_copy(table_name, "TO STDOUT"))

    File.write!("/tmp/" <> table_name <> ".csv", response.rows)
    table_name <> ".csv"
  end

  @doc """
  Retrieve a dump of the data on user tables from a tempfile
  """
  # sobelow_skip ["SQL.Stream", "Traversal"]
  def restore_from_dump(table_name) do
    file_name = table_name <> ".csv"
    stream = SQL.stream(Repo, postgres_copy(table_name, "FROM STDIN"))
    table_data = File.read!("/tmp/" <> file_name)
    {:ok, _} = Repo.transaction(fn -> Enum.into([table_data], stream) end)
    file_name
  end

  # sobelow_skip ["Traversal"]
  def delete_temp_file(file_name), do: File.rm!("/tmp/" <> file_name)

  defp postgres_copy(table_name, to_or_from) do
    "COPY #{table_name} #{to_or_from} DELIMITER ',' CSV HEADER;"
  end
end
