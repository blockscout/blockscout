defmodule Explorer.Repo.Local.Migrations.LockStatsTable do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION celo_transaction_stats_trigger_func() RETURNS trigger
    LANGUAGE plpgsql AS
    $$BEGIN

    LOCK TABLE celo_transaction_stats IN EXCLUSIVE MODE;

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
  end

  def down do
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
  end
end
