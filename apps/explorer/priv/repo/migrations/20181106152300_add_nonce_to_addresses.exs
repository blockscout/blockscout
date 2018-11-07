defmodule Explorer.Repo.Migrations.AddNonceToAddresses do
  use Ecto.Migration

  def up do
    # Add nonce
    alter table(:addresses) do
      add(:nonce, :integer)
    end

    # Populate nonce field from transactions table
    # Commented out due to running time concerns
    # execute("""
    #     WITH t AS (
    #         SELECT from_address_hash AS hash, MAX(nonce) AS nonce
    #         FROM transactions
    #         GROUP BY hash
    #     )
    #  UPDATE addresses AS a
    #     SET nonce = t.nonce
    #     FROM t
    #     WHERE a.hash = t.hash
    # """)
  end

  def down do
    # Remove nonce
    alter table(:addresses) do
      remove(:nonce)
    end
  end
end
