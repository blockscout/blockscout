defmodule Explorer.Repo.Migrations.AddTokenIdsToAddressTokenBalances do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:owner_address_hash, :bytea, null: true)
      add(:owner_updated_at_block, :bigint, null: true)
      add(:owner_updated_at_log_index, :integer, null: true)
    end

    create(index(:token_instances, [:owner_address_hash]))
  end
end
