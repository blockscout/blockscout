defmodule Explorer.Account.WatchlistAddress do
  @moduledoc """
    WatchlistAddress entity
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.Account.Notifier.ForbiddenAddress
  alias Explorer.Account.Watchlist
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}

  schema "account_watchlist_addresses" do
    field(:name, :string)
    belongs_to(:address, Address, foreign_key: :address_hash, references: :hash, type: Hash.Address)
    belongs_to(:watchlist, Watchlist)

    field(:watch_coin_input, :boolean, default: true)
    field(:watch_coin_output, :boolean, default: true)
    field(:watch_erc_20_input, :boolean, default: true)
    field(:watch_erc_20_output, :boolean, default: true)
    field(:watch_erc_721_input, :boolean, default: true)
    field(:watch_erc_721_output, :boolean, default: true)
    field(:watch_erc_1155_input, :boolean, default: true)
    field(:watch_erc_1155_output, :boolean, default: true)
    field(:notify_email, :boolean, default: true)
    field(:notify_epns, :boolean)
    field(:notify_feed, :boolean)
    field(:notify_inapp, :boolean)

    timestamps()
  end

  @attrs ~w(name address_hash watch_coin_input watch_coin_output watch_erc_20_input watch_erc_20_output watch_erc_721_input watch_erc_721_output watch_erc_1155_input watch_erc_1155_output notify_email notify_epns notify_feed notify_inapp watchlist_id)a

  @doc false
  def changeset(watchlist_address, attrs \\ %{}) do
    watchlist_address
    |> cast(attrs, @attrs)
    |> validate_length(:name, min: 1, max: 35)
    |> validate_required([:name, :address_hash, :watchlist_id], message: "Required")
    |> unique_constraint([:watchlist_id, :address_hash], message: "Address already added to the watchlist")
    |> check_address()
    |> foreign_key_constraint(:address_hash, message: "")
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  defp check_address(%Changeset{changes: %{address_hash: address_hash}, valid?: true} = changeset) do
    with {:ok, address_hash} <- ForbiddenAddress.check(address_hash),
         {:ok, %Address{}} <- Chain.find_or_insert_address_from_hash(address_hash, []) do
      changeset
    else
      {:error, reason} ->
        add_error(changeset, :address_hash, reason)

      _ ->
        add_error(changeset, :address_hash, "Address error")
    end
  end

  defp check_address(changeset), do: changeset

  def watchlist_address_by_id_and_watchlist_id_query(watchlist_address_id, watchlist_id)
      when not is_nil(watchlist_address_id) and not is_nil(watchlist_id) do
    __MODULE__
    |> where([wl_address], wl_address.watchlist_id == ^watchlist_id and wl_address.id == ^watchlist_address_id)
  end

  def watchlist_address_by_id_and_watchlist_id_query(_, _), do: nil

  def get_watchlist_address_by_id_and_watchlist_id(watchlist_address_id, watchlist_id)
      when not is_nil(watchlist_address_id) and not is_nil(watchlist_id) do
    watchlist_address_id
    |> watchlist_address_by_id_and_watchlist_id_query(watchlist_id)
    |> Repo.one()
  end

  def get_watchlist_address_by_id_and_watchlist_id(_, _), do: nil

  def delete(watchlist_address_id, watchlist_id)
      when not is_nil(watchlist_address_id) and not is_nil(watchlist_id) do
    watchlist_address_id
    |> watchlist_address_by_id_and_watchlist_id_query(watchlist_id)
    |> Repo.delete_all()
  end

  def delete(_, _), do: nil

  def update(%{id: id, watchlist_id: watchlist_id} = attrs) do
    with watchlist_address <- get_watchlist_address_by_id_and_watchlist_id(id, watchlist_id),
         false <- is_nil(watchlist_address) do
      watchlist_address
      |> changeset(attrs)
      |> Repo.update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end
end
