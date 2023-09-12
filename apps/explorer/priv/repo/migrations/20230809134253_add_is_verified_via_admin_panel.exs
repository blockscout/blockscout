defmodule Explorer.Repo.Migrations.AddIsVerifiedViaAdminPanel do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:is_verified_via_admin_panel, :boolean, null: true, default: false)
    end
  end
end
