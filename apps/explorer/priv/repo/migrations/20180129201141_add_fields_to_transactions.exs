defmodule Explorer.Repo.Migrations.AddFieldsToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :gas, :numeric, precision: 100, null: false
      add :gas_price, :numeric, precision: 100, null: false
      add :input, :text, null: false
      add :nonce, :integer, null: false
      add :public_key, :string, null: false
      add :r, :string, null: false
      add :s, :string, null: false
      add :standard_v, :string, null: false
      add :transaction_index, :string, null: false
      add :v, :string, null: false
    end
  end
end
