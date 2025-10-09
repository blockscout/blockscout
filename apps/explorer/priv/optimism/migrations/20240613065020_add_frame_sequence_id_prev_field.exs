defmodule Explorer.Repo.Optimism.Migrations.AddFrameSequenceIdPrevField do
  use Ecto.Migration

  def change do
    alter table(:op_transaction_batches) do
      add(:frame_sequence_id_prev, :bigint, default: 0, null: false)
    end

    create(index(:op_frame_sequences, :view_ready))
  end
end
