defmodule Explorer.Repo.Migrations.MigrateAddressForeignKeys do
  use Ecto.Migration

  def up do
   query = "SELECT transaction_id, address_id FROM to_addresses"
    Ecto.Adapters.SQL.query!(Explorer.Repo, query, [])
    |> Map.fetch!(:rows)
    |> Enum.each(&update_to_address/1)

    query = "SELECT transaction_id, address_id FROM from_addresses"
    Ecto.Adapters.SQL.query!(Explorer.Repo, query, [])
    |> Map.fetch!(:rows)
    |> Enum.each(&update_from_address/1)


    create index(:transactions, :to_address_id)
    create index(:transactions, :from_address_id)
  end

  def down do
    remove index(:transactions, :to_address_id)
    remove index(:transactions, :from_address_id)
  end

  def update_to_address([transaction_id, address_id]) do
    query = "UPDATE transactions SET to_address_id = #{address_id} WHERE id = #{transaction_id}"
    Ecto.Adapters.SQL.query!(Explorer.Repo, query, [])
  end
  def update_to_address(_), do: nil

  def update_from_address([transaction_id, address_id]) do
    query = "UPDATE transactions SET from_address_id = #{address_id} WHERE id = #{transaction_id}"
    Ecto.Adapters.SQL.query!(Explorer.Repo, query, [])
  end
  def update_from_address(_), do: nil
end
