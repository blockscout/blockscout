defmodule :"Elixir.Explorer.Repo.Migrations.Remove-tx-actions" do
  use Ecto.Migration

  def change do
    drop(table(:transaction_actions))

    execute("DROP TYPE transaction_actions_protocol")

    execute("DROP TYPE transaction_actions_type")
  end
end
