defmodule Explorer.Account.Watchlist do
  @moduledoc """
    Watchlist is root entity for WatchlistAddresses
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Multi
  alias Explorer.Account.{Identity, WatchlistAddress}

  @derive {Jason.Encoder, only: [:name, :watchlist_addresses]}
  typed_schema "account_watchlists" do
    field(:name, :string, null: false)
    belongs_to(:identity, Identity)
    has_many(:watchlist_addresses, WatchlistAddress)

    timestamps()
  end

  @doc false
  def changeset(watchlist, attrs) do
    watchlist
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  @doc """
  Acquires data for merging from the database.

  This function is used to fetch data from the database in preparation for a merge operation.
  It retrieves both the primary watchlist and the watchlists to be merged.

  ## Parameters

    * `multi` - An `Ecto.Multi` struct representing the current multi-operation transaction.
    * `primary_id` - An integer representing the ID of the primary identity.
    * `ids_to_merge` - A list of integers representing the IDs of the identities to be merged.

  ## Returns

  Returns an updated `Ecto.Multi` struct with two additional operations:

    * `:acquire_primary_watchlist` - Fetches the watchlists associated with the primary identity.
    * `:acquire_watchlists_to_merge` - Fetches the watchlists associated with the identities to be merged.

  ## Notes

  This function is typically used as part of a larger transaction process for merging watchlists.
  It prepares the data needed for the merge without actually performing the merge operation.
  """
  @spec acquire_for_merge(Multi.t(), integer(), [integer()]) :: Multi.t()
  def acquire_for_merge(multi, primary_id, ids_to_merge) do
    multi
    |> Multi.run(:acquire_primary_watchlist, fn repo, _ ->
      {:ok, repo.all(from(watchlist in __MODULE__, where: watchlist.identity_id == ^primary_id))}
    end)
    |> Multi.run(:acquire_watchlists_to_merge, fn repo, _ ->
      {:ok, repo.all(from(watchlist in __MODULE__, where: watchlist.identity_id in ^ids_to_merge))}
    end)
  end

  @doc """
  Adds an operation to acquire and lock a watchlist record in a database transaction.

  Performs a SELECT FOR UPDATE on the watchlist record to prevent concurrent
  modifications until the transaction is committed or rolled back.

  ## Parameters
  - `multi`: An Ecto.Multi struct containing a series of database operations
  - `watchlist_id`: The ID of the watchlist to lock

  ## Returns
  An updated Ecto.Multi struct with the `:acquire_watchlist` operation that will:
  - Return `{:ok, watchlist}` if the watchlist is found and locked
  - Return `{:error, :not_found}` if no watchlist exists with the given ID
  """
  @spec acquire_with_lock(Multi.t(), integer()) :: Multi.t()
  def acquire_with_lock(multi, watchlist_id) do
    Multi.run(multi, :acquire_watchlist, fn repo, _ ->
      watchlist_query = from(watchlist in __MODULE__, where: watchlist.id == ^watchlist_id, lock: "FOR UPDATE")

      case repo.one(watchlist_query) do
        nil ->
          {:error, :not_found}

        watchlist ->
          {:ok, watchlist}
      end
    end)
  end
end
