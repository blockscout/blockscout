defmodule Explorer.Account.WatchlistNotification do
  @moduledoc """
    Strored notification about event 
    related to WatchlistAddress
  """

  use Explorer.Schema

  import Ecto.Changeset
  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  alias Explorer.Account.WatchlistAddress

  schema "account_watchlist_notifications" do
    field(:amount, :decimal)
    field(:block_number, :integer)
    field(:direction, :string)
    field(:method, :string)
    field(:tx_fee, :decimal)
    field(:type, :string)
    field(:viewed_at, :integer)
    field(:name, Explorer.Encrypted.Binary)
    field(:subject, Explorer.Encrypted.Binary)
    field(:subject_hash, Cloak.Ecto.SHA256)

    belongs_to(:watchlist_address, WatchlistAddress)

    field(:from_address_hash, Explorer.Encrypted.AddressHash)
    field(:to_address_hash, Explorer.Encrypted.AddressHash)
    field(:transaction_hash, Explorer.Encrypted.TransactionHash)

    field(:from_address_hash_hash, Cloak.Ecto.SHA256)
    field(:to_address_hash_hash, Cloak.Ecto.SHA256)
    field(:transaction_hash_hash, Cloak.Ecto.SHA256)

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
    |> put_hashed_fields()
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> put_change(:from_address_hash_hash, hash_to_lower_case_string(get_field(changeset, :from_address_hash)))
    |> put_change(:to_address_hash_hash, hash_to_lower_case_string(get_field(changeset, :to_address_hash)))
    |> put_change(:transaction_hash_hash, hash_to_lower_case_string(get_field(changeset, :transaction_hash)))
    |> put_change(:subject_hash, get_field(changeset, :subject))
  end
end
