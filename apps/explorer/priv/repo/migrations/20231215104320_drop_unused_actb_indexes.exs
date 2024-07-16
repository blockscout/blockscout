defmodule Explorer.Repo.Migrations.DropUnusedActbIndexes do
  use Ecto.Migration

  def change do
    drop(
      index(
        :address_current_token_balances,
        [:value],
        name: :address_current_token_balances_value,
        where: "value IS NOT NULL"
      )
    )

    drop(
      index(
        :address_current_token_balances,
        [:address_hash, :block_number, :token_contract_address_hash]
      )
    )
  end
end
