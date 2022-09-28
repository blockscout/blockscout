defmodule Explorer.Repo.Migrations.AddBlockNumberToCeloAccountsEpochs do
  use Ecto.Migration

  def up do
    alter table(:celo_accounts_epochs) do
      add(:block_number, :integer, default: 0)
    end

    execute("""
    UPDATE celo_accounts_epochs r
    SET block_number = b.number
    FROM blocks b
    WHERE b.hash = r.block_hash;
    """)

    create(
      index(
        :celo_accounts_epochs,
        [:account_hash, :block_number]
      )
    )
  end

  def down do
    drop(
      index(
        :celo_accounts_epochs,
        [:account_hash, :block_number]
      )
    )

    alter table(:celo_accounts_epochs) do
      remove(:block_number)
    end
  end
end
