defmodule Explorer.Repo.Migrations.AddMsgHashForL1ToL2 do
  use Ecto.Migration

  def change do
     alter table(:l1_to_l2) do
       add(:msg_hash, :bytea, null: true)
       add(:status, :string, null: true)
       modify(:l2_hash, :bytea, null: true)
     end
  end
end
