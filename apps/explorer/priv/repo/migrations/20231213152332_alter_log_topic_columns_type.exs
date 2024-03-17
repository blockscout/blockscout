defmodule Explorer.Repo.Migrations.AlterLogTopicColumnsType do
  use Ecto.Migration

  def change do
    execute("""
    ALTER TABLE logs
    ALTER COLUMN first_topic TYPE bytea
    USING CAST(REPLACE(first_topic, '0x', '\\x') as bytea),
    ALTER COLUMN second_topic TYPE bytea
    USING CAST(REPLACE(second_topic, '0x', '\\x') as bytea),
    ALTER COLUMN third_topic TYPE bytea
    USING CAST(REPLACE(third_topic, '0x', '\\x') as bytea),
    ALTER COLUMN fourth_topic TYPE bytea
    USING CAST(REPLACE(fourth_topic, '0x', '\\x') as bytea)
    ;
    """)
  end
end
