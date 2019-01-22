defmodule Explorer.Repo.Migrations.BlockSecondDegreeRelationsCompositePrimaryKey do
  use Ecto.Migration

  def up do
    # Don't use `modify` as it requires restating the whole column description
    execute("ALTER TABLE block_second_degree_relations ADD PRIMARY KEY (nephew_hash, uncle_hash)")
  end

  def down do
    execute("ALTER TABLE block_second_degree_relations DROP CONSTRAIN block_second_degree_relations_pkey")
  end
end
