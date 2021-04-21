defmodule Explorer.Repo.Migrations.SupportSourcify do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:verified_via_sourcify, :boolean, null: true)
    end

    create table(:smart_contracts_additional_sources) do
      add(:file_name, :string, null: false)
      add(:contract_source_code, :text, null: false)

      add(:address_hash, references(:smart_contracts, column: :address_hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      timestamps()
    end

    create(index(:smart_contracts_additional_sources, :address_hash))
  end
end
