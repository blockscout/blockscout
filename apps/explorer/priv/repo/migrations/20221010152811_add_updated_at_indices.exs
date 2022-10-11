defmodule Explorer.Repo.Migrations.AddUpdatedAtIndices do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  @tables ~w(
    celo_account
    celo_accounts_epochs
    celo_election_rewards
    celo_voter_rewards
    celo_voter_votes
    token_instances
  )a

  def change do
    for table <- @tables, do: create_if_not_exists(index(table, [:updated_at], concurrently: true))
  end
end
