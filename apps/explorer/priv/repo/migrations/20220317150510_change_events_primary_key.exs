defmodule Explorer.Repo.Migrations.ChangeEventsPrimaryKey do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # use block_number in primary key
    alter table(:celo_contract_events) do
      remove(:block_hash)
      modify(:block_number, :integer, primary_key: true, null: false)
      modify(:log_index, :integer, primary_key: true, null: false)
      modify(:topic, :string, null: false)
    end

    # add indices to block_number and topic
    create(index(:celo_contract_events, :block_number))
    create(index(:celo_contract_events, :topic))
  end

  def down do
    alter table(:celo_contract_events) do
      add(:block_hash, :bytea)
    end

    flush()

    from(e in "celo_contract_events",
      join: b in "blocks",
      on: b.number == e.block_number,
      update: [set: [block_hash: b.hash]]
    )
    |> repo().update_all([])

    drop(constraint(:celo_contract_events, :celo_contract_events_pkey))

    alter table(:celo_contract_events) do
      modify(:block_number, :integer, primary_key: false)
      modify(:block_hash, :bytea, primary_key: true, null: false)
      modify(:log_index, :integer, primary_key: true, null: false)
      modify(:topic, :string, null: true)
    end

    drop(index(:celo_contract_events, :block_number))
    drop(index(:celo_contract_events, :topic))
  end
end
