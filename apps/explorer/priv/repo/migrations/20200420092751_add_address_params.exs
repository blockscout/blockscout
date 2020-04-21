defmodule Explorer.Repo.Migrations.AddAddressParams do
  use Ecto.Migration

  def change do
    alter table(:celo_params) do
      add(:address_value, :bytea)
    end
  end
end
