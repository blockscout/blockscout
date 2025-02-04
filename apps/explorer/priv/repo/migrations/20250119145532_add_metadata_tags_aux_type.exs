defmodule Explorer.Repo.Migrations.AddMetadataTagsAuxType do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TYPE metadata_tag_record AS (
      id integer,
      address_hash bytea,
      metadata jsonb,
      addresses_index integer
    );
    """)
  end

  def down do
    execute("""
    DROP TYPE metadata_tag_record;
    """)
  end
end
