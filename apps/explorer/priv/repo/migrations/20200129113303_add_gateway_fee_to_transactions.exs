defmodule Explorer.Repo.Migrations.AddGatewayFeeToTransactions do
  @moduledoc """
  """

  use Ecto.Migration

  def up do
    alter table("transactions") do
      add(:gateway_fee, :numeric, precision: 100, null: true)
    end

    alter table("internal_transactions") do
      add(:gateway_fee, :numeric, precision: 100, null: true)
    end
  end

  def down do
    alter table("transactions") do
      remove(:gateway_fee)
    end

    alter table("internal_transactions") do
      remove(:gateway_fee)
    end
  end
end
