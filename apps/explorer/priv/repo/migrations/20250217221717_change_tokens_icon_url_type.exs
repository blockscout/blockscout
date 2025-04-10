defmodule Explorer.Repo.Migrations.ChangeTokensIconUrlType do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      modify(:icon_url, :text, null: true)
    end
  end
end
