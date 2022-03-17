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
  end

  def down do
    alter table(:celo_contract_events) do
      remove(:block_number)
      remove(:topic)
    end
  end
end
