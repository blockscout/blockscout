defmodule Explorer.Repo.Celo.Migrations.SetRefetchNeededForL2Blocks do
  use Ecto.Migration

  def change do
    l2_migration_block_number = Application.get_env(:explorer, :celo)[:l2_migration_block]

    if l2_migration_block_number do
      execute(
        "UPDATE blocks SET refetch_needed = true WHERE number >= #{l2_migration_block_number}",
        "UPDATE blocks SET refetch_needed = false WHERE number >= #{l2_migration_block_number}"
      )
    end
  end
end
