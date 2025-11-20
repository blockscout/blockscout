defmodule Explorer.Repo.Zilliqa.Migrations.CreateZRC2TokenTables do
  use Ecto.Migration

  def up do
    create table(:zilliqa_zrc2_token_adapters, primary_key: false) do
      add(:zrc2_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:adapter_address_hash, references(:addresses, column: :hash, type: :bytea), primary_key: true)
      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:zilliqa_zrc2_token_adapters, :zrc2_address_hash))

    create table(:zilliqa_zrc2_token_transfers, primary_key: false) do
      add(
        :transaction_hash,
        references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        primary_key: true
      )

      add(:log_index, :integer, primary_key: true)
      add(:from_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:to_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:amount, :decimal, null: false)
      add(:zrc2_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:block_number, :integer, null: false)
      add(:block_hash, references(:blocks, column: :hash, type: :bytea), primary_key: true)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:zilliqa_zrc2_token_transfers, :zrc2_address_hash))
    create(index(:zilliqa_zrc2_token_transfers, [:block_number, :block_hash]))
  end

  def down do
    drop_if_exists(table(:zilliqa_zrc2_token_transfers))
    drop_if_exists(table(:zilliqa_zrc2_token_adapters))
  end
end
