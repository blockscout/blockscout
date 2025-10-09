defmodule Explorer.Repo.Migrations.ChangeChainIdTypeInSignedAuthorization do
  use Ecto.Migration

  def up do
    alter table(:signed_authorizations) do
      modify(:chain_id, :numeric, precision: 78, scale: 0)
    end
  end

  def down do
    alter table(:signed_authorizations) do
      modify(:chain_id, :bigint)
    end
  end
end
