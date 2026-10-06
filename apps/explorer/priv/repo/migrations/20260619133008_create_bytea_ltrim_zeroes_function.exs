# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.CreateByteaLtrimZeroesFunction do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION bytea_ltrim_zeroes(b BYTEA)
    RETURNS BYTEA AS $$
    DECLARE
        i INT := 0;
    BEGIN
        WHILE i < octet_length(b) AND get_byte(b, i) = 0 LOOP
            i := i + 1;
        END LOOP;
        RETURN substr(b, i + 1);
    END;
    $$ LANGUAGE plpgsql IMMUTABLE STRICT;
    """)
  end

  def down do
    execute("DROP FUNCTION IF EXISTS bytea_ltrim_zeroes(b BYTEA);")
  end
end
