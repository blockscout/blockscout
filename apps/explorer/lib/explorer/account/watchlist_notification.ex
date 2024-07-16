defmodule Explorer.Account.WatchlistNotification do
  @moduledoc """
    Stored notification about event
    related to WatchlistAddress
  """

  use Explorer.Schema

  import Ecto.Changeset
  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  alias Explorer.Repo
  alias Explorer.Account.{Watchlist, WatchlistAddress}

  typed_schema "account_watchlist_notifications" do
    field(:amount, :decimal, null: false)
    field(:block_number, :integer, null: false)
    field(:direction, :string, null: false)
    field(:method, :string, null: false)
    field(:tx_fee, :decimal, null: false)
    field(:type, :string, null: false)
    field(:viewed_at, :integer, null: false)
    field(:name, Explorer.Encrypted.Binary, null: false)
    field(:subject, Explorer.Encrypted.Binary)
    field(:subject_hash, Cloak.Ecto.SHA256) :: binary() | nil

    belongs_to(:watchlist_address, WatchlistAddress)
    belongs_to(:watchlist, Watchlist)

    field(:from_address_hash, Explorer.Encrypted.AddressHash)
    field(:to_address_hash, Explorer.Encrypted.AddressHash)
    field(:transaction_hash, Explorer.Encrypted.TransactionHash)

    field(:from_address_hash_hash, Cloak.Ecto.SHA256) :: binary() | nil
    field(:to_address_hash_hash, Cloak.Ecto.SHA256) :: binary() | nil
    field(:transaction_hash_hash, Cloak.Ecto.SHA256) :: binary() | nil

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
    # Using force_change instead of put_change due to https://github.com/danielberkompas/cloak_ecto/issues/53
    changeset
    |> force_change(:from_address_hash_hash, hash_to_lower_case_string(get_field(changeset, :from_address_hash)))
    |> force_change(:to_address_hash_hash, hash_to_lower_case_string(get_field(changeset, :to_address_hash)))
    |> force_change(:transaction_hash_hash, hash_to_lower_case_string(get_field(changeset, :transaction_hash)))
    |> force_change(:subject_hash, get_field(changeset, :subject))
  end

  @doc """
    Check if amount of watchlist notifications for the last 30 days is less than ACCOUNT_WATCHLIST_NOTIFICATIONS_LIMIT_FOR_30_DAYS
  """
  @spec limit_reached_for_watchlist_id?(integer) :: boolean
  def limit_reached_for_watchlist_id?(watchlist_id) do
    __MODULE__
    |> where(
      [wn],
      wn.watchlist_id == ^watchlist_id and
        fragment("NOW() - ? at time zone 'UTC' <= interval '30 days'", wn.inserted_at)
    )
    |> limit(^watchlist_notification_30_days_limit())
    |> Repo.account_repo().aggregate(:count) == watchlist_notification_30_days_limit()
  end

  defp watchlist_notification_30_days_limit do
    Application.get_env(:explorer, Explorer.Account)[:notifications_limit_for_30_days]
  end
end
