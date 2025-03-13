defmodule Explorer.Repo.Migrations.RemoveDecompiledSmartContractsTable do
  use Ecto.Migration

  def change do
    execute("""
    CREATE OR REPLACE FUNCTION drop_empty_table(t_name character varying)
    RETURNS void AS
    $BODY$
    DECLARE
        x BOOLEAN;
    BEGIN
        IF EXISTS
            ( SELECT 1
              FROM   information_schema.tables
              WHERE  table_name = format('%I', t_name)
            )
        THEN
          EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I) t', t_name) INTO x;
          IF x = False THEN
              EXECUTE format('DROP TABLE IF EXISTS %I', t_name);
          END IF;
          RETURN;
        END IF;
    END;
    $BODY$
    LANGUAGE plpgsql VOLATILE
    """)

    execute("""
      SELECT drop_empty_table('decompiled_smart_contracts')
    """)

    execute("""
      DROP FUNCTION drop_empty_table(t_name character varying)
    """)
  end
end
