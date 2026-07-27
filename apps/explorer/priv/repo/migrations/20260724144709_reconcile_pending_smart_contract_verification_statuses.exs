# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.ReconcilePendingSmartContractVerificationStatuses do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE smart_contract_verification_statuses st
    SET status = 1, updated_at = now()
    FROM smart_contracts s
    WHERE st.contract_address_hash = s.address_hash
      AND st.status = 0
    """)
  end

  def down do
    :ok
  end
end
