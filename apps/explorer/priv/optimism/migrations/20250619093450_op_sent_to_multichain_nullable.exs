defmodule Explorer.Repo.Optimism.Migrations.OPSentToMultichainNullable do
  use Ecto.Migration

  def change do
    alter table(:op_interop_messages) do
      modify(:sent_to_multichain, :boolean, null: true, default: nil)
    end
  end
end
