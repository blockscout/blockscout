defmodule Explorer.Repo.Optimism.Migrations.OPInteropTransferFields do
  use Ecto.Migration

  def change do
    execute("TRUNCATE TABLE op_interop_messages;")

    alter table(:op_interop_messages) do
      add(:transfer_token_address_hash, :bytea, null: true, default: nil)
      add(:transfer_from_address_hash, :bytea, null: true, default: nil)
      add(:transfer_to_address_hash, :bytea, null: true, default: nil)
      add(:transfer_amount, :decimal, null: true, default: nil)
      add(:sent_to_multichain, :boolean, null: false, default: false)
    end
  end
end
