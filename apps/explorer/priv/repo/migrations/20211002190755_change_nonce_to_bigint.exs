defmodule Explorer.Repo.Migrations.ChangeNonceToBigint do
  use Ecto.Migration

  def up do
    alter table(:transactions) do
      modify(:nonce, :bigint)
    end

    alter table(:addresses) do
      modify(:nonce, :bigint)
    end
  end

  def down do
    alter table(:transactions) do
      modify(:nonce, :integer)
    end

    alter table(:addresses) do
      modify(:nonce, :integer)
    end
  end
end
