defmodule Explorer.Repo.Migrations.CreateBlockSecondDegreeRelations do
  use Ecto.Migration

  def change do
    create table(:block_second_degree_relations, primary_key: false) do
      add(:nephew_hash, references(:blocks, column: :hash, type: :bytea), null: false)
      add(:uncle_hash, :bytea, null: false)
      add(:uncle_fetched_at, :utc_datetime_usec, default: fragment("NULL"), null: true)
    end

    create(unique_index(:block_second_degree_relations, [:nephew_hash, :uncle_hash], name: :nephew_hash_to_uncle_hash))

    create(
      unique_index(:block_second_degree_relations, [:nephew_hash, :uncle_hash],
        name: :unfetched_uncles,
        where: "uncle_fetched_at IS NULL"
      )
    )

    create(unique_index(:block_second_degree_relations, [:uncle_hash, :nephew_hash], name: :uncle_hash_to_nephew_hash))
  end
end
