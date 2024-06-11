defmodule Explorer.Repo.Migrations.AddCdnUploadError do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:cdn_upload_error, :string, null: true)
    end
  end
end
