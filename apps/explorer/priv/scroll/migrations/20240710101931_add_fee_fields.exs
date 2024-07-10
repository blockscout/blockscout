defmodule Explorer.Repo.Scroll.Migrations.AddFeeFields do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:l1_fee, :numeric, precision: 100, null: true)
    end
  end
end
