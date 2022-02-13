defmodule Explorer.Accounts.WatchlistNotification do
  @moduledoc """
    Strored notification about event 
    related to WatchlistAddress
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Explorer.Accounts.WatchlistAddress

  alias Explorer.Chain.{
    Address,
    Hash,
    Transaction
  }

  schema "account_watchlist_notifications" do
    field(:amount, :decimal)
    field(:block_number, :integer)
    field(:direction, :string)
    field(:method, :string)
    field(:name, :string)
    field(:tx_fee, :decimal)
    field(:type, :string)
    field(:viewed_at, :integer)

    belongs_to(:watchlist_address, WatchlistAddress)

    belongs_to(
      :from_address,
      Address,
      foreign_key: :from_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :to_address,
      Address,
      foreign_key: :to_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      references: :hash,
      type: Hash.Full
    )

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
