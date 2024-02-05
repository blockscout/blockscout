defmodule Explorer.Repo.Migrations.AddTokenTypeToTokenTransfers do
  use Ecto.Migration

  def change do
    alter table(:token_transfers) do
      add_if_not_exists(:token_type, :string)
    end

    create_if_not_exists(index(:token_transfers, :token_type))
  end
end
