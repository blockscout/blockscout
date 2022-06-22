defmodule Explorer.Repo.Migrations.SetCountersOnTransactionTable do
  use Ecto.Migration

  def up do
    execute("CREATE TABLE celo_transaction_stats(stat_type varchar(255), value numeric(100,0));")

    # coalesce gas_used values to prevent null propogation when gas used is null
    execute("""
    CREATE OR REPLACE FUNCTION celo_transaction_stats_trigger_func() RETURNS trigger
    LANGUAGE plpgsql AS
    $$BEGIN
    IF TG_OP = 'INSERT' THEN
      UPDATE celo_transaction_stats SET value = value + 1 WHERE stat_type = 'total_transaction_count';
      UPDATE celo_transaction_stats SET value = value + coalesce(NEW.gas_used, 0) WHERE stat_type = 'total_gas_used';

      RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
      UPDATE celo_transaction_stats SET value = value - 1 WHERE stat_type = 'total_transaction_count';
      UPDATE celo_transaction_stats SET value = value - coalesce(OLD.gas_used, 0) WHERE stat_type = 'total_gas_used';

      RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
      UPDATE celo_transaction_stats SET value = value + (coalesce(NEW.gas_used, 0) - coalesce(OLD.gas_used, 0)) WHERE stat_type = 'total_gas_used';

      RETURN NEW;
    ELSIF TG_OP = 'TRUNCATE' THEN
      UPDATE celo_transaction_stats SET value = 0 WHERE stat_type = 'total_transaction_count';
      UPDATE celo_transaction_stats SET value = 0 WHERE stat_type = 'total_gas_used';

      RETURN NULL;
    END IF;
    END;$$;
    """)

    execute("""
    CREATE CONSTRAINT TRIGGER celo_transaction_stats_modified
    AFTER INSERT OR DELETE OR UPDATE ON transactions
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE PROCEDURE celo_transaction_stats_trigger_func();
    """)

    # TRUNCATE triggers must be FOR EACH STATEMENT
    execute("""
    CREATE TRIGGER celo_transaction_stats_truncated AFTER TRUNCATE ON transactions
    FOR EACH STATEMENT EXECUTE PROCEDURE celo_transaction_stats_trigger_func();
    """)

    execute(
      "INSERT INTO celo_transaction_stats VALUES ('total_transaction_count', (SELECT count(*) FROM transactions));"
    )

    execute("INSERT INTO celo_transaction_stats VALUES ('total_gas_used', (SELECT sum(gas_used) FROM transactions));")
  end

  def down do
    execute("DROP TRIGGER celo_transaction_stats_truncated ON transactions;")
    execute("DROP TRIGGER celo_transaction_stats_modified ON transactions;")
    execute("DROP FUNCTION celo_transaction_stats_trigger_func();")
    execute("DROP TABLE celo_transaction_stats;")
  end
end
