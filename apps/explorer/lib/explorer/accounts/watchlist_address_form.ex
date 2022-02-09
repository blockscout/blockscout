defmodule Explorer.Accounts.WatchlistAddressForm do
  @moduledoc """
    WatchlistAddressForm 
    needed for substitute WatchlistAddress, 
    because of nft boolean fields expand to 721 & 1155
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Explorer.Accounts.Watchlist
  alias Explorer.Chain.{Address, Hash}

  embedded_schema do
    field(:name, :string)
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)
    belongs_to(:watchlist, Watchlist)

    field(:watch_coin_input, :boolean, default: true)
    field(:watch_coin_output, :boolean, default: true)
    field(:watch_erc_20_input, :boolean, default: true)
    field(:watch_erc_20_output, :boolean, default: true)
    field(:watch_nft_input, :boolean, default: true)
    field(:watch_nft_output, :boolean, default: true)
    field(:notify_email, :boolean, default: true)
    field(:notify_epns, :boolean, default: true)
    field(:notify_feed, :boolean, default: true)
    field(:notify_inapp, :boolean, default: true)

    timestamps()
  end

  @doc false
  def changeset(watchlist_address, attrs) do
    watchlist_address
    |> cast(attrs, [
      :name,
      :address_hash,
      :watch_coin_input,
      :watch_coin_output,
      :watch_erc_20_input,
      :watch_erc_20_output,
      :watch_nft_input,
      :watch_nft_output,
      :notify_email,
      :notify_epns,
      :notify_feed,
      :notify_inapp
    ])
    |> validate_required([:name, :address_hash])
  end
end
