defmodule Explorer.Repo.Migrations.AddRefetchNeededToBlock do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:refetch_needed, :boolean, default: false)
    end

    execute("UPDATE blocks SET refetch_needed = TRUE WHERE consensus", "")
  end
end
