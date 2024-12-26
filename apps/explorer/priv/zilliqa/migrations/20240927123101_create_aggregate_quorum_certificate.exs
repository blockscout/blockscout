defmodule Explorer.Repo.Zilliqa.Migrations.CreateAggregateQuorumCertificate do
  use Ecto.Migration

  def change do
    create table(:zilliqa_aggregate_quorum_certificates, primary_key: false) do
      add(
        :block_hash,
        references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      add(:view, :integer, null: false)
      add(:signature, :binary, null: false)

      timestamps()
    end
  end
end
