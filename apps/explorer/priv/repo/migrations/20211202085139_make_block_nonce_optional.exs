defmodule Explorer.Repo.Migrations.MakeBlockNonceOptional do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      modify(:nonce, :bytea, null: true)
    end
  end
end
