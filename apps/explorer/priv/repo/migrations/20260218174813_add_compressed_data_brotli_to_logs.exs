defmodule Explorer.Repo.Migrations.AddCompressedDataBrotliToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:compressed_data_brotli, :bytea, null: true)
    end
  end
end
