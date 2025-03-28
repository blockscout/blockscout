defmodule Explorer.Repo.Migrations.SignedAuthorizationsNonceChangeTypeToNumeric do
  use Ecto.Migration

  def up do
    alter table(:signed_authorizations) do
      modify(:nonce, :numeric, precision: 20, scale: 0)
    end
  end

  def down do
    alter table(:signed_authorizations) do
      modify(:nonce, :integer)
    end
  end
end
