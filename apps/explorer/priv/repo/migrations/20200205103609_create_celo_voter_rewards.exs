defmodule Explorer.Repo.Migrations.CreateCeloVoterRewards do
  use Ecto.Migration

  def change do
    create table(:celo_voter_rewards) do
      add(:block_hash, :bytea, null: false)
      add(:log_index, :integer, null: false)
      add(:block_number, :integer, null: false)
      add(:reward, :numeric, precision: 100)
      add(:active_votes, :numeric, precision: 100)
      add(:address_hash, :bytea, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_voter_rewards, [:block_hash, :log_index], unique: true))

    execute("""
    create materialized view celo_accumulated_rewards as
    select address_hash, sum(active_votes) as active, sum(reward) as reward
    from celo_voter_rewards, (select max(block_number) as max_block_number from celo_voter_rewards) as t
    where block_number > max_block_number - 100
    group by address_hash
    """)

    execute("""
      CREATE OR REPLACE FUNCTION refresh_rewards()
      RETURNS trigger AS $$
      BEGIN
        REFRESH MATERIALIZED VIEW celo_accumulated_rewards;
        RETURN NULL;
      END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER refresh_rewards_trg
    AFTER INSERT OR UPDATE OR DELETE
    ON celo_voter_rewards
    FOR EACH STATEMENT
    EXECUTE PROCEDURE refresh_rewards()
    """)
  end
end
