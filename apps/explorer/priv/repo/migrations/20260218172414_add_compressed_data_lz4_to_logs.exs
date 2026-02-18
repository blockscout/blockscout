defmodule Explorer.Repo.Migrations.AddCompressedDataLz4ToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:compressed_data_lz4, :bytea, null: true)
    end
  end
end
