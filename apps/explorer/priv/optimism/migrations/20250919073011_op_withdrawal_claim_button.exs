defmodule Explorer.Repo.Optimism.Migrations.OPWithdrawalClaimButton do
  use Ecto.Migration

  def change do
    execute("""
    CREATE OR REPLACE FUNCTION convert_numeric_to_bytea(n NUMERIC, zero_left_pad INT default 32) RETURNS BYTEA AS $$
    DECLARE
        result BYTEA := '';
        v INT;
        i INT := 0;
    BEGIN
        WHILE n > 0 LOOP
            v := n % 256;
            result := SET_BYTE(('\\x00' || result), 0, v);
            n := (n - v) / 256;
            i := i + 1;
        END LOOP;

        i := zero_left_pad - i;

        WHILE i > 0 LOOP
          result := '\\x00'::bytea || result;
          i := i - 1;
        END LOOP;

        RETURN result;
    END;
    $$ LANGUAGE PLPGSQL IMMUTABLE STRICT;
    """)
  end
end
