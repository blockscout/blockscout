defmodule Explorer.Repo.Migrations.AddVerifiedViaVerifierAlliance do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:verified_via_verifier_alliance, :boolean, null: true)
    end
  end
end
