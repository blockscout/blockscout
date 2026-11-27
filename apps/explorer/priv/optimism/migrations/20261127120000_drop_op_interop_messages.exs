# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Optimism.Migrations.DropOPInteropMessages do
  use Ecto.Migration

  def up do
    drop_if_exists(table(:op_interop_messages))

    execute("DELETE FROM last_fetched_counters WHERE counter_type = 'optimism_interop_messages_queue_iteration'")
  end

  def down do
    raise Ecto.MigrationError,
      message: "OP interop messages were removed from Blockscout, the op_interop_messages table cannot be restored"
  end
end
