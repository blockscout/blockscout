defmodule Explorer.Repo.Migrations.AddCompressedDataZstdToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:compressed_data_zstd, :bytea, null: true)
    end
  end
end
