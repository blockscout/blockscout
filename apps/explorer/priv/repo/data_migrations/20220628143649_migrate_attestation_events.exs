defmodule Explorer.Repo.Migrations.MigrateAttestationEvents do
  # event topics to migrate from logs table
  @topics [
    "0x3bff8b126c8f283f709ae37dc0d3fc03cae85ca4772cfb25b601f4b0b49ca6df",
    "0x7cf8b633f218e9f9bc2c06107bcaddcfee6b90580863768acdcfd4f05d7af394",
    "0x35bc19e2c74829d0a96c765bb41b09ce24a9d0757486ced0d075e79089323638",
    "0xc1f217a1246a98ce04e938768309107630ed86c1e0e9f9995af28e23a9c06178",
    "0x954fa47fa6f4e8017b99f93c73f4fbe599d786f9f5da73fe9086ab473fb455d8",
    "0x14d7ffb83f4265cb6fb62188eb603269555bf46efbc2923909ed7ac313d57af7"
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
