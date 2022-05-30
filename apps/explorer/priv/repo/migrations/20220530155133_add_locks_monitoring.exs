defmodule Explorer.Repo.Migrations.AddLocksMonitoring do
  use Ecto.Migration

  def up do
    execute("""
    CREATE VIEW dbg_lock_monitor AS (
      SELECT
        COALESCE (
          blocking.relation :: regclass :: text,
          blocking.locktype
        ) as locked_item,
        NOW() - blocked_activity.query_start AS waiting_duration,
        blocked_activity.pid AS blocked_pid,
        blocked_activity.query as blocked_query,
        blocked.mode as blocked_mode,
        blocking_activity.pid AS blocking_pid,
        blocking_activity.query as blocking_query,
        blocking.mode as blocking_mode
      FROM pg_catalog.pg_locks AS blocked
      JOIN pg_stat_activity AS blocked_activity
        ON blocked.pid = blocked_activity.pid
      JOIN pg_catalog.pg_locks AS blocking
        ON ((
          (
            blocking.transactionid = blocked.transactionid
          )
          OR (
            blocking.relation = blocked.relation
            AND blocking.locktype = blocked.locktype
          )
        )
        AND blocked.pid != blocking.pid
      )
      JOIN pg_stat_activity AS blocking_activity
        ON blocking.pid = blocking_activity.pid AND blocking_activity.datid = blocked_activity.datid
      WHERE
        NOT blocked.granted
        AND blocking_activity.datname = current_database()
    )
    """)
  end

  def down do
    execute("""
    DROP VIEW IF EXISTS dbg_lock_monitor
    """)
  end
end
