defmodule Explorer.Repo.Optimism.Migrations.OPWithdrawalClaimButton do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION numeric_to_bytea32(n NUMERIC)
    RETURNS BYTEA AS $$
    DECLARE
        zero_left_pad INT := 32;
        bytes BYTEA := repeat(E'\\\\000', zero_left_pad)::bytea; -- preallocate zero bytes
        v INT;
        pos INT := zero_left_pad - 1; -- index from rightmost byte
    BEGIN
        WHILE n > 0 AND pos >= 0 LOOP
            v := n % 256;
            bytes := set_byte(bytes, pos, v);
            n := (n - v) / 256;
            pos := pos - 1;
        END LOOP;
        RETURN bytes;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE STRICT;
    """)
  end

  def down do
    execute("DROP FUNCTION IF EXISTS numeric_to_bytea32(n NUMERIC);")
  end
end
