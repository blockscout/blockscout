defmodule Explorer.Repo.Migrations.CreateTokensPrimaryKey do
  use Ecto.Migration

  def up do
    # Don't use `modify` as it requires restating the whole column description
    execute("ALTER TABLE tokens ADD PRIMARY KEY (contract_address_hash)")
  end

  def down do
    execute("ALTER TABLE tokens DROP CONSTRAINT tokens_pkey")
  end
end
