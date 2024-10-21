defmodule Explorer.Account do
  @moduledoc """
  Context for Account module.
  """

  alias Ecto.Multi
  alias Explorer.Account.Api.Key

  alias Explorer.Account.{
    CustomABI,
    Identity,
    PublicTagsRequest,
    TagAddress,
    TagTransaction,
    Watchlist,
    WatchlistAddress,
    WatchlistNotification
  }

  alias Explorer.Repo

  def enabled? do
    Application.get_env(:explorer, __MODULE__)[:enabled]
  end

  @doc """
  Merges multiple Identity records into a primary Identity.

  This function consolidates data from multiple Identity records into a single
  primary Identity. It performs a series of merge operations for various
  associated entities (API keys, custom ABIs, public tags requests, address tags,
  transaction tags, watchlists, watchlist addresses, and watchlist notifications)
  and then deletes the merged Identity records.

  ## Parameters
  - `identities`: A list of Identity structs. The first element is considered
    the primary Identity, and the rest are merged into it.

  ## Returns
  - A tuple containing two elements:
    1. The result of the transaction:
       - `{:ok, result}` if the merge was successful
       - `{:error, failed_operation, failed_value, changes_so_far}` if an error occurred
    2. The primary Identity struct or nil if the input list was empty

  ## Process
  1. Extracts IDs from the input Identity structs
  2. Performs the following merge operations in a single database transaction:
     - Merges API keys
     - Merges custom ABIs
     - Merges public tags requests
     - Merges address tags
     - Merges transaction tags
     - Acquires and merges watchlists
     - Merges watchlist addresses
     - Merges watchlist notifications
  3. Deletes the merged Identity records
  4. Commits the transaction

  ## Notes
  - If an empty list is provided, the function returns `{{:ok, 0}, nil}`.
  - This function uses Ecto.Multi for transactional integrity.
  - All merge operations update the associated records to point to the primary Identity.
  - Some merge operations (like custom ABIs and tags) set `user_created: false` to satisfy database constraints.
  - The function relies on the account repository specified in the application configuration.
  """
  @spec merge([Identity.t()]) :: {{:ok, any()} | {:error, any()} | Multi.failure(), Identity.t() | nil}
  def merge([primary_identity | identities_to_merge]) do
    primary_identity_id = primary_identity.id
    identities_to_merge_ids = Enum.map(identities_to_merge, & &1.id)

    {Multi.new()
     |> Key.merge(primary_identity_id, identities_to_merge_ids)
     |> CustomABI.merge(primary_identity_id, identities_to_merge_ids)
     |> PublicTagsRequest.merge(primary_identity_id, identities_to_merge_ids)
     |> TagAddress.merge(primary_identity_id, identities_to_merge_ids)
     |> TagTransaction.merge(primary_identity_id, identities_to_merge_ids)
     |> Watchlist.acquire_for_merge(primary_identity_id, identities_to_merge_ids)
     |> WatchlistAddress.merge()
     |> WatchlistNotification.merge()
     |> Identity.delete(identities_to_merge_ids)
     |> Repo.account_repo().transaction(), primary_identity}
  end

  def merge([]) do
    {{:ok, 0}, nil}
  end
end
