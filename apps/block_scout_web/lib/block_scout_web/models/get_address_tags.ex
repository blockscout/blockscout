defmodule GetAddressTags do
  @moduledoc """
  Get various types of tags associated with the address
  """

  import Ecto.Query, only: [from: 2]

  alias Explorer.Accounts.{TagAddress, WatchlistAddress}
  alias Explorer.Chain.Hash
  alias Explorer.Repo
  alias Explorer.Tags.{AddressTag, AddressToTag}

  def call(nil, nil),
    do: %{personal_tags: [], watchlist_names: []}

  def call(%Hash{} = address_hash, current_user) do
    %{
      # common_tags: get_tags_on_address(address_hash),
      personal_tags: get_personal_tags(address_hash, current_user),
      watchlist_names: get_watchlist_names_on_address(address_hash, current_user)
    }
  end

  def call(_, _), do: %{personal_tags: [], watchlist_names: []}

  def get_tags_on_address(%Hash{} = address_hash) do
    query =
      from(
        tt in AddressTag,
        left_join: att in AddressToTag,
        on: tt.id == att.tag_id,
        where: att.address_hash == ^address_hash,
        where: tt.label != ^"validator",
        select: %{label: tt.label, display_name: tt.display_name}
      )

    Repo.all(query)
  end

  def get_tags_on_address(_), do: []

  def get_personal_tags(%Hash{} = address_hash, %{id: id}) do
    query =
      from(
        ta in TagAddress,
        where: ta.address_hash == ^address_hash,
        where: ta.identity_id == ^id,
        select: %{label: ta.name, display_name: ta.name}
      )

    Repo.all(query)
  end

  def get_personal_tags(_, _), do: []

  def get_watchlist_names_on_address(%Hash{} = address_hash, %{watchlist_id: watchlist_id}) do
    query =
      from(
        wa in WatchlistAddress,
        where: wa.address_hash == ^address_hash,
        where: wa.watchlist_id == ^watchlist_id,
        select: %{label: wa.name, display_name: wa.name}
      )

    Repo.all(query)
  end

  def get_watchlist_names_on_address(_, _), do: []
end
