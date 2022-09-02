defmodule Explorer.Account.WatchlistNotification do
  @moduledoc """
    Strored notification about event 
    related to WatchlistAddress
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Explorer.Account.WatchlistAddress
  alias Explorer.Chain.Hash

  schema "account_watchlist_notifications" do
    field(:amount, :decimal)
    field(:block_number, :integer)
    field(:direction, :string)
    field(:method, :string)
    field(:name, :string)
    field(:subject, :string)
    field(:tx_fee, :decimal)
    field(:type, :string)
    field(:viewed_at, :integer)

    belongs_to(:watchlist_address, WatchlistAddress)

    field(:from_address_hash, Hash.Address)
    field(:to_address_hash, Hash.Address)
    field(:transaction_hash, Hash.Full)

    timestamps()
  end

  @doc false
  def changeset(watchlist_notifications, attrs) do
    watchlist_notifications
    |> cast(attrs, [:amount, :direction, :name, :type, :method, :block_number, :tx_fee, :value, :decimals, :viewed_at])
    |> validate_required([
      :amount,
      :direction,
      :name,
      :type,
      :method,
      :block_number,
      :tx_fee,
      :value,
      :decimals,
      :viewed_at
    ])
  end
end
