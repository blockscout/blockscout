defmodule Explorer.Repo.Migrations.CreateProxyContract do
  use Ecto.Migration

  def change do
    create table(:proxy_contract) do
      add(:proxy_address, :bytea, null: false)
      add(:implementation_address, :bytea, null: false)
    end
  end
end
