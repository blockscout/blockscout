defmodule Explorer.Repo.Account.Migrations.AddApiKeysAndPlansTables do
  use Ecto.Migration

  def change do
    create table(:account_api_plans, primary_key: false) do
      add(:id, :serial, null: false, primary_key: true)
      add(:max_req_per_second, :smallint)
      add(:name, :string, null: false)

      timestamps()
    end

    create(unique_index(:account_api_plans, [:id, :max_req_per_second, :name]))

    execute(
      "INSERT INTO account_api_plans (id, max_req_per_second, name, inserted_at, updated_at) VALUES (1, 10, 'Free Plan', NOW(), NOW());"
    )

    create table(:account_api_keys, primary_key: false) do
      add(:identity_id, references(:account_identities, column: :id, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:value, :uuid, null: false, primary_key: true)

      timestamps()
    end

    alter table(:account_identities) do
      add(:plan_id, references(:account_api_plans, column: :id), default: 1)
    end

    create(index(:account_api_keys, [:identity_id]))
  end
end
