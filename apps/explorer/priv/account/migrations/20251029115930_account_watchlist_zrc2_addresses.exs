defmodule Explorer.Repo.Account.Migrations.AccountWatchlistZRC2Addresses do
  use Ecto.Migration
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :zilliqa do
    def change do
      alter table(:account_watchlist_addresses) do
        add(:watch_zrc_2_input, :boolean, default: true)
        add(:watch_zrc_2_output, :boolean, default: true)
      end
    end
  else
    def change do
      # does nothing for other chain types
    end
  end
end
