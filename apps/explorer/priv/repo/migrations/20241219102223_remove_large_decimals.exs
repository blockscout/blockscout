defmodule Explorer.Repo.Migrations.RemoveLargeDecimals do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE tokens SET decimals = NULL WHERE decimals > 78;
    """)
  end
end
