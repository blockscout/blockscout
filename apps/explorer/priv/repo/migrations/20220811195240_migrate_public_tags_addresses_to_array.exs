defmodule Explorer.Repo.Migrations.MigratePublicTagsAddressesToArray do
  use Ecto.Migration

  def change do
    alter table(:account_public_tags_requests) do
      add(:addresses_duplicate, {:array, :bytea})
    end

    execute("""
      CREATE OR REPLACE FUNCTION convert(text[]) RETURNS bytea[] AS $$
      DECLARE
        s bytea[] := ARRAY[]::bytea[];
        x text;
      BEGIN
        FOREACH x IN ARRAY $1
        LOOP
          s := array_append(s, decode(ltrim(x, '0x'), 'hex'));
        END LOOP;
        RETURN s;
      END;
      $$ LANGUAGE plpgsql;
    """)

    execute("""
      UPDATE account_public_tags_requests set addresses_duplicate = convert(string_to_array(addresses, ';'))
    """)

    alter table(:account_public_tags_requests) do
      remove(:addresses)
    end

    rename(table(:account_public_tags_requests), :addresses_duplicate, to: :addresses)
  end
end
