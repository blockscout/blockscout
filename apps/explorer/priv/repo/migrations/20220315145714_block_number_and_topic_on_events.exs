defmodule Explorer.Repo.Migrations.BlockNumberAndTopicOnEvents do
  use Ecto.Migration
  import Ecto.Query

  def up do
    # add new fields
    alter table(:celo_contract_events) do
      add(:block_number, :integer)
      add(:topic, :string)
    end

    # assert change is applied to db
    flush()

    # get block_number and event topic from "parent" log row and update existing event rows
    from(event in "celo_contract_events",
      join: log in "logs",
      on: {log.block_hash, log.index} == {event.block_hash, event.log_index},
      update: [set: [block_number: log.block_number, topic: log.first_topic]]
    )
    |> repo().update_all([])

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
      join: l in "logs",
      on: {l.block_number, l.index} == {e.block_number, e.log_index},
      update: [set: [block_hash: l.block_hash]]
    )
    |> repo().update_all([])

    alter table(:celo_contract_events) do
      remove(:block_number)
      remove(:topic)
      modify(:block_hash, :bytea, primary_key: true, null: false)
      modify(:log_index, :integer, primary_key: true, null: false)
    end
  end
end
