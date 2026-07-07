# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.AddMediaTypesToTokenInstances do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:image_type, :string, null: true)
      add(:animation_type, :string, null: true)
    end
  end
end
