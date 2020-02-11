defmodule Explorer.Repo.Migrations.CreateCeloVoterRewardsView do
  use Ecto.Migration

  def change do

    execute("""
    drop materialized view if exists celo_accumulated_rewards
    """)

    execute("""
    drop trigger if exists refresh_rewards_trg on celo_voter_rewards
    """)

    execute("""
    create materialized view celo_accumulated_rewards as
    select address_hash, sum(active_votes) as active, sum(reward) as reward,
           30*(sum(reward)/nullif(sum(active_votes),0)) as ratio
    from celo_voter_rewards as r, (select max(block_number) as max_block_number from celo_voter_rewards) as t, celo_params as p
    where r.block_number > max_block_number - 30*p.number_value
      and p.name = \'epochSize\'
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
