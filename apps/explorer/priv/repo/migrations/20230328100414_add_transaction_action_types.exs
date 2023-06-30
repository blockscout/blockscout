defmodule Explorer.Repo.Migrations.AddTransactionActionTypes do
  use Ecto.Migration

  def change do
    execute("ALTER TYPE transaction_actions_protocol ADD VALUE 'aave_v3'")
    execute("ALTER TYPE transaction_actions_type ADD VALUE 'borrow'")
    execute("ALTER TYPE transaction_actions_type ADD VALUE 'supply'")
    execute("ALTER TYPE transaction_actions_type ADD VALUE 'repay'")
    execute("ALTER TYPE transaction_actions_type ADD VALUE 'flash_loan'")
    execute("ALTER TYPE transaction_actions_type ADD VALUE 'enable_collateral'")
    execute("ALTER TYPE transaction_actions_type ADD VALUE 'disable_collateral'")
    execute("ALTER TYPE transaction_actions_type ADD VALUE 'liquidation_call'")
  end
end
