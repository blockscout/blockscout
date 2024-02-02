defmodule BlockScoutWeb.Models.GetAddressTags do
  @moduledoc """
  Get various types of tags associated with the address
  """

  import Ecto.Query, only: [from: 2]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Account.{TagAddress, WatchlistAddress}
  alias Explorer.Repo
  alias Explorer.Tags.{AddressTag, AddressToTag}

  def get_address_tags(_, _, opts \\ [])

  def get_address_tags(nil, nil, _),
    do: %{common_tags: [], personal_tags: [], watchlist_names: []}

  def get_address_tags(address_hash, current_user, opts) when not is_nil(address_hash) do
    %{
      common_tags: get_tags_on_address(address_hash, opts),
      personal_tags: get_personal_tags(address_hash, current_user),
      watchlist_names: get_watchlist_names_on_address(address_hash, current_user)
    }
  end

  def get_address_tags(_, _, _), do: %{common_tags: [], personal_tags: [], watchlist_names: []}

  def get_public_tags(address_hash, opts \\ []) when not is_nil(address_hash) do
    %{
      common_tags: get_tags_on_address(address_hash, opts)
    }
  end

  def get_tags_on_address(address_hash, opts \\ [])

  def get_tags_on_address(address_hash, opts) when not is_nil(address_hash) do
    query =
      from(
        tt in AddressTag,
        left_join: att in AddressToTag,
        on: tt.id == att.tag_id,
        where: att.address_hash == ^address_hash,
        where: tt.label != ^"validator",
        select: %{label: tt.label, display_name: tt.display_name, address_hash: att.address_hash}
      )

    select_repo(opts).all(query)
  end

  def get_tags_on_address(_, _), do: []

  def get_personal_tags(address_hash, %{id: id}) when not is_nil(address_hash) do
    query =
      from(
        ta in TagAddress,
        where: ta.address_hash_hash == ^address_hash,
        where: ta.identity_id == ^id,
        select: %{label: ta.name, display_name: ta.name, address_hash: ta.address_hash}
      )

    Repo.account_repo().all(query)
  end

  def get_personal_tags(_, _), do: []

  def get_watchlist_names_on_address(address_hash, %{watchlist_id: watchlist_id}) when not is_nil(address_hash) do
    query =
      from(
        wa in WatchlistAddress,
        where: wa.address_hash_hash == ^address_hash,
        where: wa.watchlist_id == ^watchlist_id,
        select: %{label: wa.name, display_name: wa.name}
      )

    Repo.account_repo().all(query)
  end

  def get_watchlist_names_on_address(_, _), do: []
end
