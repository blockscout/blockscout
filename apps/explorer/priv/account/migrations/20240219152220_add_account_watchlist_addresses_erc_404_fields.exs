defmodule Explorer.Repo.Account.Migrations.AddAccountWatchlistAddressesErc404Fields do
  use Ecto.Migration

  def change do
    alter table(:account_watchlist_addresses) do
      add(:watch_erc_404_input, :boolean, default: true)
      add(:watch_erc_404_output, :boolean, default: true)
    end
  end
end
