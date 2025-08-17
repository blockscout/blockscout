defmodule Explorer.Repo.Account.Migrations.CreateSmartContractAdditionalSourcesUniqueIndex do
  use Ecto.Migration

  def up do
    # This deletes all duplicate rows except the one with the minimum ID
    # (keeping the earliest inserted record for each address_hash + file_name combination)
    delete_duplicates = """
    DELETE FROM smart_contracts_additional_sources
    WHERE id IN (
      SELECT id
      FROM (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY address_hash, file_name ORDER BY id) as row_number
        FROM smart_contracts_additional_sources
      ) t
      WHERE t.row_number > 1
    )
    """

    execute(delete_duplicates)

    create(
      unique_index(
        :smart_contracts_additional_sources,
        [:file_name, :address_hash]
      )
    )
  end

  def down do
    drop(
      unique_index(
        :smart_contracts_additional_sources,
        [:file_name, :address_hash]
      )
    )
  end
end
