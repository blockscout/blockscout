defmodule Explorer.Repo.Account.Migrations.CreateAccountWatchlistAddresses do
  use Ecto.Migration

  def change do
    create table(:account_watchlist_addresses) do
      add(:name, :string)
      add(:address_hash, :bytea, null: false)
      add(:watchlist_id, references(:account_watchlists, on_delete: :delete_all))
      add(:watch_coin_input, :boolean, default: true)
      add(:watch_coin_output, :boolean, default: true)
      add(:watch_erc_20_input, :boolean, default: true)
      add(:watch_erc_20_output, :boolean, default: true)
      add(:watch_erc_721_input, :boolean, default: true)
      add(:watch_erc_721_output, :boolean, default: true)
      add(:watch_erc_1155_input, :boolean, default: true)
      add(:watch_erc_1155_output, :boolean, default: true)
      add(:notify_email, :boolean, default: true)
      add(:notify_epns, :boolean, default: false)
      add(:notify_feed, :boolean, default: true)
      add(:notify_inapp, :boolean, default: false)

      timestamps()
    end

    create(index(:account_watchlist_addresses, [:watchlist_id]))
    create(index(:account_watchlist_addresses, [:address_hash]))
  end
end
