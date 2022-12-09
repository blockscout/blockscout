defmodule Explorer.Repo.Migrations.DropUnfetchedTokenBalancesIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(
      unique_index(
        :address_token_balances,
        [:address_hash, :token_contract_address_hash, "COALESCE(token_id, -1)", :block_number],
        name: :unfetched_token_balances,
        where: "value_fetched_at IS NULL"
      )
    )
  end
end
