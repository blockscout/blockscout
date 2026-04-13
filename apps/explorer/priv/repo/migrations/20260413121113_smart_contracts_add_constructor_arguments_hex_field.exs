defmodule Explorer.Repo.Migrations.SmartContractsAddConstructorArgumentsHexField do
  use Ecto.Migration

  def up do
    alter table(:smart_contracts) do
      add(:constructor_arguments_hex, :bytea)
    end

    execute("""
      UPDATE smart_contracts
      SET constructor_arguments_hex = decode(regexp_replace(constructor_arguments, '^0[xX]', ''), 'hex')
      WHERE constructor_arguments IS NOT NULL
        AND regexp_replace(constructor_arguments, '^0[xX]', '') ~ '^[0-9A-Fa-f]*$'
        AND mod(length(regexp_replace(constructor_arguments, '^0[xX]', '')), 2) = 0;
    """)

    alter table(:smart_contracts) do
      remove(:constructor_arguments)
    end

    execute("ALTER TABLE smart_contracts RENAME COLUMN constructor_arguments_hex TO constructor_arguments")
  end

  def down do
    alter table(:smart_contracts) do
      add(:constructor_arguments_text, :text)
    end

    execute("""
      UPDATE smart_contracts
      SET constructor_arguments_text = encode(constructor_arguments, 'hex')
      WHERE constructor_arguments IS NOT NULL;
    """)

    alter table(:smart_contracts) do
      remove(:constructor_arguments)
    end

    execute("ALTER TABLE smart_contracts RENAME COLUMN constructor_arguments_text TO constructor_arguments")
  end
end
