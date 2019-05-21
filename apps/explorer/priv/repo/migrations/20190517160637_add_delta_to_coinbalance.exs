defmodule Explorer.Repo.Migrations.AddDeltaToCoinbalance do
  use Ecto.Migration

  def change do
    alter table(:address_coin_balances) do
      add(:delta, :numeric, precision: 100, default: nil, null: true)
      add(:delta_updated_at, :utc_datetime_usec, default: nil, null: true)
    end

    execute(
      """
      UPDATE "address_coin_balances" cb
      SET delta = value - COALESCE((
            SELECT cbp.value
            FROM "address_coin_balances" cbp
            WHERE cbp.value IS NOT NULL
              AND cbp.block_number < cb.block_number
              AND cbp.address_hash = cb.address_hash
            ORDER BY cbp.block_number DESC
            FETCH FIRST ROW ONLY
          ), 0),
          "delta_updated_at" = NOW()
      """,
      ""
    )
  end
end
