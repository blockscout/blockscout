defmodule Explorer.Repo.Migrations.AddUnindexedCodeIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(
        :transactions,
        [:block_number],
        name: "unindexed_code",
        where:
          "((block_hash IS NOT NULL) AND (created_contract_code_indexed_at IS NULL) AND (created_contract_address_hash IS NOT NULL))"
      )
    )
  end
end
