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
