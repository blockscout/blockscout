# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Models.GetAddressTags do
  @moduledoc """
  Get various types of tags associated with the address
  """

  import Ecto.Query, only: [from: 2, select_merge: 3, where: 3]

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

  @doc """
  Same as `get_address_tags/3` for multiple addresses at once, using a single
  query per tag type instead of a query per address per tag type.

  Returns a map keyed by address hash with values of the same shape as
  `get_address_tags/3` returns.
  """
  def get_address_tags_batch(address_hashes, current_user, opts \\ [])

  def get_address_tags_batch([], _, _), do: %{}

  def get_address_tags_batch(address_hashes, current_user, opts) do
    common_tags = address_hashes |> get_tags_on_addresses(opts) |> Enum.group_by(& &1.address_hash)

    personal_tags = address_hashes |> get_personal_tags_on_addresses(current_user) |> Enum.group_by(& &1.address_hash)

    watchlist_names =
      address_hashes
      |> get_watchlist_names_on_addresses(current_user)
      |> Enum.group_by(& &1.address_hash, &Map.delete(&1, :address_hash))

    Map.new(address_hashes, fn address_hash ->
      {address_hash,
       %{
         common_tags: Map.get(common_tags, address_hash, []),
         personal_tags: Map.get(personal_tags, address_hash, []),
         watchlist_names: Map.get(watchlist_names, address_hash, [])
       }}
    end)
  end

  def get_public_tags(address_hash, opts \\ []) when not is_nil(address_hash) do
    %{
      common_tags: get_tags_on_address(address_hash, opts)
    }
  end

  def get_tags_on_address(address_hash, opts \\ [])

  def get_tags_on_address(address_hash, opts) when not is_nil(address_hash) do
    common_tags_base_query()
    |> where([tt, att], att.address_hash == ^address_hash)
    |> select_repo(opts).all()
  end

  def get_tags_on_address(_, _), do: []

  defp get_tags_on_addresses(address_hashes, opts) do
    common_tags_base_query()
    |> where([tt, att], att.address_hash in ^address_hashes)
    |> select_repo(opts).all()
  end

  defp common_tags_base_query do
    from(
      tt in AddressTag,
      left_join: att in AddressToTag,
      on: tt.id == att.tag_id,
      where: tt.label != ^"validator",
      select: %{label: tt.label, display_name: tt.display_name, address_hash: att.address_hash}
    )
  end

  def get_personal_tags(address_hash, %{id: id}) when not is_nil(address_hash) do
    id
    |> personal_tags_base_query()
    |> where([ta], ta.address_hash_hash == ^address_hash)
    |> Repo.account_repo().all()
  end

  def get_personal_tags(_, _), do: []

  defp get_personal_tags_on_addresses(address_hashes, %{id: id}) do
    id
    |> personal_tags_base_query()
    |> where([ta], ta.address_hash_hash in ^address_hashes)
    |> Repo.account_repo().all()
  end

  defp get_personal_tags_on_addresses(_, _), do: []

  defp personal_tags_base_query(identity_id) do
    from(
      ta in TagAddress,
      where: ta.identity_id == ^identity_id,
      select: %{label: ta.name, display_name: ta.name, address_hash: ta.address_hash}
    )
  end

  def get_watchlist_names_on_address(address_hash, %{watchlist_id: watchlist_id}) when not is_nil(address_hash) do
    watchlist_id
    |> watchlist_names_base_query()
    |> where([wa], wa.address_hash_hash == ^address_hash)
    |> Repo.account_repo().all()
  end

  def get_watchlist_names_on_address(_, _), do: []

  defp get_watchlist_names_on_addresses(address_hashes, %{watchlist_id: watchlist_id}) do
    watchlist_id
    |> watchlist_names_base_query()
    |> where([wa], wa.address_hash_hash in ^address_hashes)
    |> select_merge([wa], %{address_hash: wa.address_hash})
    |> Repo.account_repo().all()
  end

  defp get_watchlist_names_on_addresses(_, _), do: []

  # `address_hash` is not selected here on purpose: the per-address variant
  # returns these maps directly in the API response, so the batch variant
  # `select_merge`s it in only for grouping.
  defp watchlist_names_base_query(watchlist_id) do
    from(
      wa in WatchlistAddress,
      where: wa.watchlist_id == ^watchlist_id,
      select: %{label: wa.name, display_name: wa.name}
    )
  end
end
