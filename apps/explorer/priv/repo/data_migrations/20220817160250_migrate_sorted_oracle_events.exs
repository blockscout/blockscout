defmodule Explorer.Repo.Migrations.MigrateSortedOracleEvents do
  # event topics to migrate from logs table
  @topics [
    "0x6dc84b66cc948d847632b9d829f7cb1cb904fbf2c084554a9bc22ad9d8453340",
    "0xc68a9b88effd8a11611ff410efbc83569f0031b7bc70dd455b61344c7f0a042f",
    "0xf8324c8592dfd9991ee3e717351afe0a964605257959e3d99b0eb3d45bff9422"
  ]

  use Explorer.Repo.Migrations.DataMigration
  import Ecto.Query

  @doc "Undo the data migration"
  def down, do: :ok

  @doc "Returns an ecto query that gives the next batch / page of source rows to be processed"
  def page_query(start_of_page) do
    event_page_query(start_of_page)
  end

  @doc "Perform the transformation with the list of source rows to operate upon, returns a list of inserted / modified ids"
  def do_change(ids) do
    event_change(ids)
  end

  @doc "Handle unsuccessful insertions"
  def handle_non_insert(ids), do: raise("Failed to insert - #{inspect(ids)}")
end
