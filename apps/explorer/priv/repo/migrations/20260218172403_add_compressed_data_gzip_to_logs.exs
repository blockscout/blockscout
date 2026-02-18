defmodule Explorer.Repo.Migrations.AddCompressedDataGzipToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:compressed_data_gzip, :bytea, null: true)
    end
  end
end
