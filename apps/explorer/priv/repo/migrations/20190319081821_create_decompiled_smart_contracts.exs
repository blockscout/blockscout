defmodule Explorer.Repo.Migrations.CreateDecompiledSmartContracts do
  use Ecto.Migration

  def change do
    create table(:decompiled_smart_contracts) do
      add(:decompiler_version, :string, null: false)
      add(:decompiled_source_code, :text, null: false)
      add(:address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)

      timestamps()
    end

    create(unique_index(:decompiled_smart_contracts, :address_hash))
  end
end
