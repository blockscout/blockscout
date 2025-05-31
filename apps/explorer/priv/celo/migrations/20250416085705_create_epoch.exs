defmodule Explorer.Repo.Celo.Migrations.CreateEpoch do
  use Ecto.Migration

  def change do
    create table(:celo_epochs, primary_key: false) do
      add(:number, :smallint, null: false, primary_key: true)
      add(:is_fetched, :boolean, null: false, default: false)

      add(:start_block_number, :integer)
      add(:end_block_number, :integer)

      add(
        :start_processing_block_hash,
        references(
          :blocks,
          column: :hash,
          type: :bytea,
          on_delete: :delete_all
        )
      )

      add(
        :end_processing_block_hash,
        references(
          :blocks,
          column: :hash,
          type: :bytea,
          on_delete: :delete_all
        )
      )

      timestamps()
    end

    l2_migration_block_number = Application.get_env(:explorer, :celo)[:l2_migration_block]

    if l2_migration_block_number do
      execute("""
      WITH epoch_blocks AS (
        SELECT
          b.number AS block_number,
          b.hash AS block_hash,
          FLOOR(b.number / 17280) AS epoch_number
        FROM celo_pending_epoch_block_operations op
        JOIN blocks b ON op.block_hash = b.hash
        WHERE b.consensus = true AND b.number > 0 AND b.number < #{l2_migration_block_number}
      )
      INSERT INTO celo_epochs (
        number,
        start_processing_block_hash,
        end_processing_block_hash,
        start_block_number,
        end_block_number,
        inserted_at,
        updated_at
      )
      SELECT
        epoch_number,
        block_hash AS start_processing_block_hash,
        block_hash AS end_processing_block_hash,
        ((epoch_number - 1) * 17280) AS start_block_number,
        (block_number - 1) AS end_block_number,
        NOW(),
        NOW()
      FROM epoch_blocks
      """)

      execute("""
      WITH epoch_blocks AS (
        SELECT
          b.number AS block_number,
          b.hash AS block_hash,
          FLOOR(b.number / 17280) AS epoch_number
        FROM blocks b
        WHERE
          b.consensus = true AND
          b.number > 0 AND
          b.number < #{l2_migration_block_number} AND
          b.number % 17280 = 0 AND
          NOT EXISTS (
            SELECT 1 FROM celo_epochs e
            WHERE e.number = FLOOR(b.number / 17280)
          )
      )
      INSERT INTO celo_epochs (
        number,
        is_fetched,
        start_processing_block_hash,
        end_processing_block_hash,
        start_block_number,
        end_block_number,
        inserted_at,
        updated_at
      )
      SELECT
        epoch_number,
        true AS is_fetched,
        block_hash AS start_processing_block_hash,
        block_hash AS end_processing_block_hash,
        ((epoch_number - 1) * 17280) AS start_block_number,
        (epoch_number * 17280 - 1) AS end_block_number, -- End at last block of epoch
        NOW(),
        NOW()
      FROM epoch_blocks
      """)
    end
  end
end
