defmodule Explorer.Repo.Migrations.RemoveLegacyOptimismPortalContractConstant do
  use Ecto.Migration

  def up do
    execute("DELETE FROM constants WHERE key = 'optimism_portal_contract_address'")
  end

  def down do
    :ok
  end
end
