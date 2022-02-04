defmodule Explorer.Repo.Migrations.CreateCeloContractEvents do
  use Ecto.Migration

  def change do
    create table("celo_contract_events", primary_key: false) do
      add(:block_hash, references("blocks", column: :hash, type: :bytea, name: :block_hash))
      add(:log_index, :integer)

      add(
        :transaction_hash,
        references("transactions", column: :hash, type: :bytea, name: :transaction_hash),
        null: true
      )

      add(
        :contract_address_hash,
        references("addresses", column: :hash, type: :bytea, name: :contract_address_hash),
        null: true
      )

      add(:params, :map, default: %{})
      add(:name, :string)

      timestamps()
    end

    create(index(:celo_contract_events, [:name]))
    create(index(:celo_contract_events, [:transaction_hash]))
    create(index(:celo_contract_events, [:block_hash]))
    create(index(:celo_contract_events, [:contract_address_hash]))

    execute(
      "CREATE INDEX celo_contract_events_params_index ON celo_contract_events USING GIN(params)",
      "DROP INDEX celo_contract_events_params_index"
    )

    execute(
      "ALTER TABLE celo_contract_events ADD PRIMARY KEY (block_hash, log_index)",
      "ALTER TABLE celo_contract_events DROP CONSTRAINT celo_contract_events_pkey"
    )
  end
end
