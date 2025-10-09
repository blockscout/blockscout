defmodule Explorer.Repo.Celo.Migrations.AddEpochRewards do
  use Ecto.Migration

  def change do
    create table(:celo_epoch_rewards, primary_key: false) do
      add(:reserve_bolster_transfer_log_index, :integer)
      add(:community_transfer_log_index, :integer)
      add(:carbon_offsetting_transfer_log_index, :integer)

      add(
        :block_hash,
        references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      timestamps()
    end

    execute(
      """
      ALTER TABLE celo_epoch_rewards
      ADD CONSTRAINT celo_epoch_rewards_reserve_bolster_transfer_log_index_fkey
      FOREIGN KEY (reserve_bolster_transfer_log_index, block_hash)
      REFERENCES token_transfers (log_index, block_hash)
      ON DELETE CASCADE
      """,
      """
      ALTER TABLE celo_epoch_rewards
      DROP CONSTRAINT celo_epoch_rewards_reserve_bolster_transfer_log_index_fkey
      """
    )

    execute(
      """
      ALTER TABLE celo_epoch_rewards
      ADD CONSTRAINT celo_epoch_rewards_community_transfer_log_index_fkey
      FOREIGN KEY (community_transfer_log_index, block_hash)
      REFERENCES token_transfers (log_index, block_hash)
      ON DELETE CASCADE
      """,
      """
      ALTER TABLE celo_epoch_rewards
      DROP CONSTRAINT celo_epoch_rewards_community_transfer_log_index_fkey
      """
    )

    execute(
      """
      ALTER TABLE celo_epoch_rewards
      ADD CONSTRAINT celo_epoch_rewards_carbon_offsetting_transfer_log_index_fkey
      FOREIGN KEY (carbon_offsetting_transfer_log_index, block_hash)
      REFERENCES token_transfers (log_index, block_hash)
      ON DELETE CASCADE
      """,
      """
      ALTER TABLE celo_epoch_rewards
      DROP CONSTRAINT celo_epoch_rewards_carbon_offsetting_transfer_log_index_fkey
      """
    )
  end
end
