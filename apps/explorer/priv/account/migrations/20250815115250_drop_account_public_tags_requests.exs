defmodule Explorer.Repo.Account.Migrations.DropAccountPublicTagsRequests do
  use Ecto.Migration

  def change do
    drop(table(:account_public_tags_requests))
  end
end
