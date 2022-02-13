defmodule Explorer.Accounts.WatchlistAddress do
  @moduledoc """
    WatchlistAddress entity
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Explorer.Accounts.{Watchlist, WatchlistAddress, WatchlistAddressForm}
  alias Explorer.Chain.{Address, Hash}

  schema "account_watchlist_addresses" do
    field(:name, :string)
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)
    belongs_to(:watchlist, Watchlist)

    field(:watch_coin_input, :boolean)
    field(:watch_coin_output, :boolean)
    field(:watch_erc_20_input, :boolean)
    field(:watch_erc_20_output, :boolean)
    field(:watch_erc_721_input, :boolean)
    field(:watch_erc_721_output, :boolean)
    field(:watch_erc_1155_input, :boolean)
    field(:watch_erc_1155_output, :boolean)
    field(:notify_email, :boolean)
    field(:notify_epns, :boolean)
    field(:notify_feed, :boolean)
    field(:notify_inapp, :boolean)

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
      :watch_erc_721_input,
      :watch_erc_721_output,
      :watch_erc_1155_input,
      :watch_erc_1155_output,
      :notify_email,
      :notify_epns,
      :notify_feed,
      :notify_inapp
    ])
    |> validate_required([:name, :address_hash])
  end

  def to_form(%WatchlistAddress{} = wa) do
    %WatchlistAddressForm{
      address_hash: wa.address.hash,
      name: wa.name,
      watch_coin_input: wa.watch_coin_input,
      watch_coin_output: wa.watch_coin_output,
      watch_erc_20_input: wa.watch_erc_20_input,
      watch_erc_20_output: wa.watch_erc_20_output,
      watch_nft_input: wa.watch_erc_721_input,
      watch_nft_output: wa.watch_erc_721_output,
      notify_email: wa.notify_email
    }
  end
end
