defmodule Explorer.Repo.Migrations.RenameMediaUrls do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE token_instances SET media_urls=NULL, media_type=NULL where media_urls IS NOT NULL;
    """)

    rename(table(:token_instances), :media_urls, to: :thumbnails)
  end
end
