defmodule Explorer.Repo.Account.Migrations.RemoveAbusedPublicTagsRequest do
  use Ecto.Migration

  def up do
    execute("""
    WITH ranked_public_tags_requests AS (SELECT id,
                                                identity_id,
                                                ROW_NUMBER() OVER (
                                                    PARTITION BY identity_id
                                                    ) as row_number
                                        FROM account_public_tags_requests)
    DELETE
    FROM account_public_tags_requests
    WHERE id IN (SELECT id
                FROM ranked_public_tags_requests
                WHERE row_number > 15)
    """)
  end
end
