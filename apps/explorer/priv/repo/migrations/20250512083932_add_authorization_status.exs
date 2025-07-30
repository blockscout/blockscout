defmodule Explorer.Repo.Migrations.AddAuthorizationStatus do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE signed_authorization_status AS ENUM ('ok', 'invalid_chain_id', 'invalid_signature', 'invalid_nonce')",
      "DROP TYPE signed_authorization_status"
    )

    alter table(:signed_authorizations) do
      add(:status, :signed_authorization_status, null: true)
    end
  end
end
