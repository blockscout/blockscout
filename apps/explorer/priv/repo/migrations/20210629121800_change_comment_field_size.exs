defmodule Explorer.Repo.Migrations.ChangeCommentFieldSize do
  use Ecto.Migration

  def change do
    alter table(:token_transfers) do
      modify(:comment, :text)
    end
  end
end
