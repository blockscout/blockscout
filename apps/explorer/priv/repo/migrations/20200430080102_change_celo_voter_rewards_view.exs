defmodule Explorer.Repo.Migrations.ChangeCeloVoterRewardsView do
  use Ecto.Migration

  def up do
    execute("""
    create or replace view celo_rewards_view as
    select address_hash, sum(active_votes) as active, sum(reward) as reward,
           (sum(reward*total_active_votes/total_reward)/nullif(sum(active_votes),0)) as ratio
    from celo_voter_rewards as r, (select max(block_number) as max_block_number from celo_voter_rewards) as t, celo_params as p
    where r.block_number > max_block_number - 28*p.number_value
      and p.name = \'epochSize\'
    group by address_hash
    """)
  end

  def down do
    # Go back to the previous definition
    execute("""
    create or replace view celo_rewards_view as
    select address_hash, sum(active_votes) as active, sum(reward) as reward,
           (sum(reward)*sum(total_active_votes)/nullif(sum(total_reward)*sum(active_votes),0)) as ratio
    from celo_voter_rewards as r, (select max(block_number) as max_block_number from celo_voter_rewards) as t, celo_params as p
    where r.block_number > max_block_number - 28*p.number_value
      and p.name = \'epochSize\'
    group by address_hash
    """)
  end
end
