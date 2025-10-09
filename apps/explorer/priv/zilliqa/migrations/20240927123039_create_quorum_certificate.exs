defmodule Explorer.Repo.Zilliqa.Migrations.CreateQuorumCertificate do
  use Ecto.Migration

  def change do
    create table(:zilliqa_quorum_certificates, primary_key: false) do
      add(
        :block_hash,
        references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      add(:view, :integer, null: false)
      add(:signature, :binary, null: false)
      add(:signers, {:array, :smallint}, null: false)

      timestamps()
    end
  end
end
