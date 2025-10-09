defmodule Explorer.Repo.Optimism.Migrations.RenameInteropAddresses do
  use Ecto.Migration

  def change do
    rename(table(:op_interop_messages), :sender, to: :sender_address_hash)
    rename(table(:op_interop_messages), :target, to: :target_address_hash)
  end
end
