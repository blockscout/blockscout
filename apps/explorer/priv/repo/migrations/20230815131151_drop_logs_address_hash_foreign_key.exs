# cspell:ignore fkey
defmodule Explorer.Repo.Migrations.DropLogsAddressHashForeignKey do
  use Ecto.Migration

  def change do
    drop_if_exists(constraint(:logs, :logs_address_hash_fkey))
  end
end
