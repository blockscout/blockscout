defmodule Explorer.Repo.Migrations.FaucetAddPhoneHash do
  use Ecto.Migration

  def change do
    alter table("faucet_requests") do
      modify(:receiver_hash, :bytea, primary_key: true)
      add(:phone_hash, :bytea, null: false, primary_key: true)
      add(:session_key_hash, :bytea, null: false, primary_key: true)
      add(:verification_code_hash, :bytea)
      add(:verification_code_validation_attempts, :integer)
      add(:coins_sent, :boolean, default: false)
    end

    create(index(:faucet_requests, [:phone_hash, :coins_sent]))
  end
end
