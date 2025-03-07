defmodule Explorer.Repo.Migrations.RemoveDecompiledSmartContractsTable do
  use Ecto.Migration

  def change do
    execute("""
    CREATE OR REPLACE FUNCTION public.drop_empty_table(t_schema character varying, t_name character varying)
    RETURNS void AS
    $BODY$
    DECLARE
        x BOOLEAN;
    BEGIN
        IF EXISTS
            ( SELECT 1
              FROM   information_schema.tables
              WHERE  table_schema = format('%I', t_schema)
              AND    table_name = format('%I', t_name)
            )
        THEN
          EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I.%I) t', t_schema, t_name) INTO x;
          IF x = False THEN
              EXECUTE format('DROP TABLE IF EXISTS %I.%I', t_schema, t_name);
          END IF;
          RETURN;
        END IF;
    END;
    $BODY$
    LANGUAGE plpgsql VOLATILE
    """)

    execute("""
      SELECT drop_empty_table('public', 'decompiled_smart_contracts')
    """)
  end
end
