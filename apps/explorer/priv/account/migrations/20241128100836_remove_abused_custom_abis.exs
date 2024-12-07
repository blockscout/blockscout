defmodule Explorer.Repo.Account.Migrations.RemoveAbusedCustomAbis do
  use Ecto.Migration

  def up do
    execute("""
    WITH ranked_abis AS (SELECT id,
                                identity_id,
                                ROW_NUMBER() OVER (
                                    PARTITION BY identity_id
                                    ) as row_number
                        FROM account_custom_abis)
    DELETE
    FROM account_custom_abis
    WHERE id IN (SELECT id
                FROM ranked_abis
                WHERE row_number > 15)
    """)
  end
end
