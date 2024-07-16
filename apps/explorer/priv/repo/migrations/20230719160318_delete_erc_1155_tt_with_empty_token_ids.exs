defmodule Explorer.Repo.Migrations.DeleteErc1155TtWithEmptyTokenIds do
  use Ecto.Migration

  def change do
    execute("""
    DELETE from token_transfers USING tokens WHERE token_transfers.token_contract_address_hash = tokens.contract_address_hash AND tokens.type = 'ERC-1155' AND (token_transfers.token_ids IS NULL OR ARRAY_LENGTH(token_transfers.token_ids, 1) = 0) ;
    """)
  end
end
