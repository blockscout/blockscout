defmodule Explorer.Repo.Migrations.AddCompressedDataToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:compressed_data, :bytea)
      modify(:data, :bytea, null: true)
    end
  end
end
