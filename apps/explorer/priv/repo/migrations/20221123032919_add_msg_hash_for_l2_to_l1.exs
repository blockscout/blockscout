defmodule Explorer.Repo.Migrations.AddMsgHashForL2ToL1 do
  use Ecto.Migration

  def change do
     alter table(:l2_to_l1) do
       add(:msg_hash, :bytea, null: true)
     end
  end
end
