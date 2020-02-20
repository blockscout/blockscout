defmodule Explorer.Repo.Migrations.CreateCeloVoterRewardsView do
  use Ecto.Migration

  def up do

    execute("""
    create or replace view celo_rewards_view as
    select address_hash, sum(active_votes) as active, sum(reward) as reward,
           (sum(reward)*sum(total_active_votes)/nullif(sum(total_reward)*sum(active_votes),0)) as ratio
    from celo_voter_rewards as r, (select max(block_number) as max_block_number from celo_voter_rewards) as t, celo_params as p
    where r.block_number > max_block_number - 28*p.number_value
      and p.name = \'epochSize\'
    group by address_hash
    """)

    execute("""
    create materialized view celo_accumulated_rewards as
    select address as address_hash, active, reward, ratio
    from ( celo_validator_group left outer join celo_rewards_view ON address_hash = address) 
    """)

    execute("""
    create or replace view celo_attestations_requested as
    select address, count(*) as requested from logs, celo_account where first_topic='0xaf7f470b643316cf44c1f2898328a075e7602945b4f8584f48ba4ad2d8a2ea9d' and fourth_topic='0x000000000000000000000000'||encode(address::bytea, 'hex') group by address
    """)

    execute("""
    create or replace view celo_attestations_fulfilled as
    select address, count(*) as fulfilled from logs, celo_account where first_topic='0x414ff2c18c092697c4b8de49f515ac44f8bebc19b24553cf58ace913a6ac639d' and fourth_topic='0x000000000000000000000000'||encode(address::bytea, 'hex') group by address
    """)

    execute("""
    create materialized view celo_attestation_stats as
    select 0 as id, a.address as address_hash, requested, fulfilled
    from ((celo_account as a left outer join celo_attestations_requested as b on a.address=b.address)
          left outer join celo_attestations_fulfilled as c on a.address = c.address)
    """)

  end

  def down do
    execute("""
    drop trigger if exists refresh_rewards_trg on celo_voter_rewards
    """)

    execute("""
    drop materialized view if exists celo_accumulated_rewards
    """)

    execute("""
    drop materialized view if exists celo_attestation_stats
    """)

    execute("""
    drop view if exists celo_rewards_view
    """)

    execute("""
    drop view if exists celo_attestations_requested
    """)

    execute("""
    drop view if exists celo_attestations_fulfilled
    """)
  end
end
