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
      )
    """)

    # Initially pre-populate all EOAs and contracts
    execute("""
      WITH tag_ids AS (
        SELECT id, label FROM address_tags
      )
      INSERT INTO address_to_tags (address_hash, tag_id, inserted_at, updated_at)
      SELECT
        s1.hash, t.id, NOW(), NOW()
      FROM (
        SELECT
          a.hash,
          CASE WHEN contract_code IS NULL THEN 'eoa' ELSE 'contract' END as label
        FROM addresses a
      ) s1
      LEFT JOIN (
        SELECT * FROM tag_ids
      ) t
      ON s1.label = t.label;
    """)

    # Pre-populate proxies
    execute("""
      WITH tag_ids AS (
        SELECT id, label FROM address_tags
      )
      INSERT INTO address_to_tags (address_hash, tag_id, inserted_at, updated_at)
      SELECT
        s.address_hash, t.id, NOW(), NOW()
      FROM smart_contracts s
      LEFT JOIN (
        SELECT * FROM tag_ids
      ) t ON t.label = 'proxy'
      WHERE implementation_name IS NOT NULL;
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
      ON s1.label = t.label;
    """)

    # Tokens
    execute("""
      WITH tag_ids AS (
        SELECT id, label FROM address_tags
      )
      INSERT INTO address_to_tags (address_hash, tag_id, inserted_at, updated_at)
      SELECT
        s.contract_address_hash, t.id, NOW(), NOW()
      FROM tokens s
      LEFT JOIN (
        SELECT * FROM tag_ids
      ) t ON t.label = 'token'
      WHERE implementation_name IS NOT NULL;
    """)
    end

  def down do
    execute("""
      DELETE FROM address_to_tags;
      DELETE FROM address_tags;
    """)
  end
end
