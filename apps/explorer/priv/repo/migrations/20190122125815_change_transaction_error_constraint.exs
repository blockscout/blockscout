defmodule Explorer.Repo.Migrations.ChangeTransactionErrorConstraint do
  use Ecto.Migration

  def change do
    drop(
      constraint(
        :transactions,
        :status
      )
    )

    create(
      constraint(
        :transactions,
        :status,
        # 0 - NULL
        # 1 - NOT NULL
        #
        # | block_hash | internal_transactions_indexed_at | status | OK | description
        # |------------|----------------------------------|--------|----|------------
        # | 0          | 0                                | 0      | 1  | pending
        # | 0          | 0                                | 1      | 0  | pending with status
        # | 0          | 1                                | 0      | 0  | pending with internal transactions
        # | 0          | 1                                | 1      | 0  | pending with internal transactions and status
        # | 1          | 0                                | 0      | 1  | pre-byzantium collated transaction without internal transactions
        # | 1          | 0                                | 1      | 1  | post-byzantium collated transaction without internal transactions
        # | 1          | 1                                | 0      | 0  | pre-byzantium collated transaction with internal transaction without status
        # | 1          | 1                                | 1      | 1  | pre- or post-byzantium collated transaction with internal transactions and status
        #
        # [Karnaugh map](https://en.wikipedia.org/wiki/Karnaugh_map)
        # b \ is | 00 | 01 | 11 | 10 |
        # -------|----|----|----|----|
        #      0 | 1  | 0  | 0  | 0  |
        #      1 | 1  | 1  | 1  | 0  |
        #
        # Simplification: ¬i·¬s + b·¬i + b·s
        check: """
        (internal_transactions_indexed_at IS NULL AND status IS NULL) OR
        (block_hash IS NOT NULL AND internal_transactions_indexed_at IS NULL) OR
        (block_hash IS NOT NULL AND status IS NOT NULL) OR
        (status = 0 and error = 'dropped/replaced')
        """
      )
    )

    drop(
      constraint(
        :transactions,
        :error
      )
    )

    create(
      constraint(
        :transactions,
        :error,
        # | status | internal_transactions_indexed_at | error    | OK         | description
        # |--------|----------------------------------|----------|------------|------------
        # | NULL   | NULL                             | NULL     | TRUE       | pending or pre-byzantium collated
        # | NULL   | NULL                             | NOT NULL | FALSE      | error cannot be known before internal transactions are indexed
        # | NULL   | NOT NULL                         | NULL     | DON'T CARE | handled by `status` check
        # | NULL   | NOT NULL                         | NOT NULL | FALSE      | error cannot be set unless status is known to be error (`0`)
        # | 0      | NULL                             | NULL     | TRUE       | post-byzantium before internal transactions indexed
        # | 0      | NULL                             | NOT NULL | FALSE      | error cannot be set unless internal transactions are indexed
        # | 0      | NOT NULL                         | NULL     | FALSE      | error MUST be set when status is error
        # | 0      | NOT NULL                         | NOT NULL | TRUE       | error is set when status is error
        # | 1      | NULL                             | NULL     | TRUE       | post-byzantium before internal transactions indexed
        # | 1      | NULL                             | NOT NULL | FALSE      | error cannot be set when status is ok
        # | 1      | NOT NULL                         | NULL     | TRUE       | error is not set when status is ok
        # | 1      | NOT NULL                         | NOT NULL | FALSE      | error cannot be set when status is ok
        #
        # Karnaugh map
        # s \ ie | NULL, NULL | NULL, NOT NULL | NOT NULL, NOT NULL | NOT NULL, NULL |
        # -------|------------|----------------|--------------------|----------------|
        # NULL   | TRUE       | FALSE          | FALSE              | DON'T CARE     |
        # 0      | TRUE       | FALSE          | TRUE               | FALSE          |
        # 1      | TRUE       | FALSE          | FALSE              | TRUE           |
        #
        check: """
        (internal_transactions_indexed_at IS NULL AND error IS NULL) OR
        (status = 0 AND internal_transactions_indexed_at IS NOT NULL AND error IS NOT NULL) OR
        (status != 0 AND internal_transactions_indexed_at IS NOT NULL AND error IS NULL) OR
        (status = 0 and error = 'dropped/replaced')
        """
      )
    )
  end
end
