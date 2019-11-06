defmodule Explorer.Repo.Migrations.CreateProxyContractIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(index("proxy_contract", [:id]))
    create(unique_index(:proxy_contract, [:proxy_address]))
  end
end
