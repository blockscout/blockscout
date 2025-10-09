defmodule Explorer.Repo.Optimism.Migrations.AddViewReadyField do
  use Ecto.Migration

  def change do
    alter table(:op_frame_sequences) do
      add(:view_ready, :boolean, default: false, null: false)
    end

    execute("UPDATE op_frame_sequences SET view_ready = TRUE")
  end
end
