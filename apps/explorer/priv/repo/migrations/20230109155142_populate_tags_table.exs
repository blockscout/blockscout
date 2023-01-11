defmodule Explorer.Repo.Local.Migrations.PopulateTagsTable do
  use Ecto.Migration

  def up do
    execute("""
      INSERT INTO address_tags (label, inserted_at, updated_at, display_name)
      VALUES
        ('black-hole', NOW(), NOW(), 'Black Hole'),
        ('eoa', NOW(), NOW(), 'EOA'),
        ('contract', NOW(), NOW(), 'contract'),
        ('proxy', NOW(), NOW(), 'proxy'),
        ('validator', NOW(), NOW(), 'validator'),
        ('validator-signer', NOW(), NOW(), 'validator signer'),
        ('validator-group', NOW(), NOW(), 'validator group'),
        ('token', NOW(), NOW(), 'token');
    """)

    execute("""
      WITH tag_id AS (
        SELECT id, label FROM address_tags
      )
      INSERT INTO address_to_tags (address_hash, tag_id, inserted_at, updated_at)
      SELECT a.address, t.id, NOW(), NOW()
      FROM ((
        SELECT
          UNNEST(ARRAY[decode('0000000000000000000000000000000000000000', 'hex'), decode('000000000000000000000000000000000000dead', 'hex')]) as address
        ) a
        CROSS JOIN (
          SELECT * FROM tag_id WHERE label='black-hole'
        ) t
        JOIN addresses adr
        ON adr.hash = a.address
      )
    """)

    execute("""
      CREATE OR REPLACE PROCEDURE update_validators_tags_bindings()
      LANGUAGE plpgsql AS $$
      BEGIN
        -- remove old addresses that are not validators anymore
        WITH existing_validators AS (
          SELECT DISTINCT
            UNNEST(ARRAY['validator', 'validator-group', 'validator-signer']) AS "label",
            UNNEST(ARRAY[address, group_address_hash, signer_address_hash]) AS "address"
          FROM celo_validator
          WHERE member > 0
        )
        DELETE FROM address_to_tags
        USING address_to_tags at
        LEFT JOIN address_tags t
        ON at.tag_id = t.id
        WHERE
          t.label IN ('validator', 'validator-group', 'validator-signer') AND
          at.address_hash NOT IN (
            SELECT address FROM existing_validators
          );

        -- insert new rows
        WITH tag_ids AS (
          SELECT id, label FROM address_tags
        )
        INSERT INTO address_to_tags (address_hash, tag_id, inserted_at, updated_at)
        SELECT
          s1.address, t.id, NOW(), NOW()
        FROM (
          SELECT DISTINCT
            UNNEST(ARRAY['validator', 'validator-group', 'validator-signer']) AS "label",
            UNNEST(ARRAY[address, group_address_hash, signer_address_hash]) AS "address"
          FROM celo_validator
          WHERE member > 0
        ) s1
        LEFT JOIN address_tags t
        ON s1.label = t.label
        JOIN addresses a
        ON s1.address = a.hash
        ON CONFLICT DO NOTHING;
      COMMIT;
      END;$$;
    """)

    # Validators, validator signers and validator groups
    execute("""
      WITH tag_ids AS (
        SELECT id, label FROM address_tags
      )
      INSERT INTO address_to_tags (address_hash, tag_id, inserted_at, updated_at)
      SELECT
        s1.address, t.id, NOW(), NOW()
      FROM (
        SELECT DISTINCT
          UNNEST(ARRAY['validator', 'validator-group', 'validator-signer']) AS "label",
          UNNEST(ARRAY[address, group_address_hash, signer_address_hash]) AS "address"
        FROM celo_validator
        WHERE member > 0
      ) s1
      LEFT JOIN address_tags t
      ON s1.label = t.label
      JOIN addresses a
      ON s1.address = a.hash;
    """)
  end

  def down do
    execute("""
      DELETE FROM address_to_tags;
      DELETE FROM address_tags;
      DROP PROCEDURE IF EXISTS update_validators_tags_bindings;
    """)
  end
end
