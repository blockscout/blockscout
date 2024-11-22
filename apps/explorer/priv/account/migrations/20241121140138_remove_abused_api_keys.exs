defmodule Explorer.Repo.Account.Migrations.RemoveAbusedApiKeys do
  use Ecto.Migration

  def up do
    execute("""
    WITH ranked_keys AS (SELECT value,
                                identity_id,
                                inserted_at,
                                ROW_NUMBER() OVER (
                                    PARTITION BY identity_id
                                    ) as row_number
                        FROM account_api_keys)
    DELETE
    FROM account_api_keys
    WHERE value IN (SELECT value
                    FROM ranked_keys
                    WHERE row_number > 3)
    """)
  end
end
