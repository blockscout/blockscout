defmodule Explorer.Repo.Migrations.AlterTransactionsAddErrorReason do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:revert_reason, :text)
    end
  end
end
