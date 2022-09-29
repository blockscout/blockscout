defmodule Explorer.Repo.Account.Migrations.CreateAccountTagAddresses do
  use Ecto.Migration

  def change do
    create table(:account_tag_addresses) do
      add(:name, :string)
      add(:identity_id, references(:account_identities, on_delete: :delete_all))

      add(:address_hash, :bytea, null: false)

      timestamps()
    end

    create(index(:account_tag_addresses, [:identity_id]))
    create(index(:account_tag_addresses, [:address_hash]))
  end
end
