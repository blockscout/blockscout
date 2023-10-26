defmodule Explorer.Account.WatchlistAddress do
  @moduledoc """
    WatchlistAddress entity
  """

  use Explorer.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Explorer.Account.Notifier.ForbiddenAddress
  alias Explorer.Account.Watchlist
  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Wei}

  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  schema "account_watchlist_addresses" do
    field(:address_hash_hash, Cloak.Ecto.SHA256)
    field(:name, Explorer.Encrypted.Binary)
    field(:address_hash, Explorer.Encrypted.AddressHash)

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

    field(:fetched_coin_balance, Wei, virtual: true)
    field(:tokens_fiat_value, :decimal, virtual: true)
    field(:tokens_count, :integer, virtual: true)
    field(:tokens_overflow, :boolean, virtual: true)

    timestamps()
  end

  @attrs ~w(name address_hash watch_coin_input watch_coin_output watch_erc_20_input watch_erc_20_output watch_erc_721_input watch_erc_721_output watch_erc_1155_input watch_erc_1155_output notify_email notify_epns notify_feed notify_inapp watchlist_id)a

  def changeset do
    %__MODULE__{}
    |> cast(%{}, @attrs)
  end

  @doc false
  def changeset(watchlist_address, attrs \\ %{}) do
    watchlist_address
    |> cast(attrs, @attrs)
    |> validate_length(:name, min: 1, max: 35)
    |> validate_required([:name, :address_hash, :watchlist_id], message: "Required")
    |> put_hashed_fields()
    |> unique_constraint([:watchlist_id, :address_hash_hash],
      name: "unique_watchlist_id_address_hash_hash_index",
      message: "Address already added to the watch list"
    )
    |> check_address()
    |> watchlist_address_count_constraint()
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> put_change(:address_hash_hash, hash_to_lower_case_string(get_field(changeset, :address_hash)))
  end

  def create(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.account_repo().insert()
  end

  def watchlist_address_count_constraint(%Changeset{changes: %{watchlist_id: watchlist_id}} = watchlist_address) do
    max_watchlist_addresses_count = get_max_watchlist_addresses_count()

    if watchlist_id
       |> watchlist_addresses_by_watchlist_id_query()
       |> limit(^max_watchlist_addresses_count)
       |> Repo.account_repo().aggregate(:count, :id) >= max_watchlist_addresses_count do
      watchlist_address
      |> add_error(:name, "Max #{max_watchlist_addresses_count} watch list addresses per account")
    else
      watchlist_address
    end
  end

  def watchlist_address_count_constraint(changeset), do: changeset

  defp check_address(%Changeset{changes: %{address_hash: address_hash}, valid?: true} = changeset) do
    check_address_inner(changeset, address_hash)
  end

  defp check_address(%Changeset{data: %{address_hash: address_hash}, valid?: true} = changeset) do
    check_address_inner(changeset, address_hash)
  end

  defp check_address(changeset), do: changeset

  defp check_address_inner(changeset, address_hash) do
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

  def watchlist_addresses_by_watchlist_id_query(watchlist_id) when not is_nil(watchlist_id) do
    __MODULE__
    |> where([wl_address], wl_address.watchlist_id == ^watchlist_id)
  end

  def watchlist_addresses_by_watchlist_id_query(_), do: nil

  @doc """
    Query paginated watchlist addresses by watchlist id
  """
  @spec get_watchlist_addresses_by_watchlist_id(integer(), [Chain.paging_options()]) :: [__MODULE__]
  def get_watchlist_addresses_by_watchlist_id(watchlist_id, options \\ [])

  def get_watchlist_addresses_by_watchlist_id(watchlist_id, options) when not is_nil(watchlist_id) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    watchlist_id
    |> watchlist_addresses_by_watchlist_id_query()
    |> order_by([wla], desc: wla.id)
    |> page_watchlist_address(paging_options)
    |> limit(^paging_options.page_size)
    |> Repo.account_repo().all()
  end

  def get_watchlist_addresses_by_watchlist_id(_, _), do: []

  defp page_watchlist_address(query, %PagingOptions{key: {id}}) do
    query
    |> where([wla], wla.id < ^id)
  end

  defp page_watchlist_address(query, _), do: query

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
    |> Repo.account_repo().one()
  end

  def get_watchlist_address_by_id_and_watchlist_id(_, _), do: nil

  def delete(watchlist_address_id, watchlist_id)
      when not is_nil(watchlist_address_id) and not is_nil(watchlist_id) do
    watchlist_address_id
    |> watchlist_address_by_id_and_watchlist_id_query(watchlist_id)
    |> Repo.account_repo().delete_all()
  end

  def delete(_, _), do: nil

  def update(%{id: id, watchlist_id: watchlist_id} = attrs) do
    with watchlist_address <- get_watchlist_address_by_id_and_watchlist_id(id, watchlist_id),
         false <- is_nil(watchlist_address) do
      watchlist_address
      |> changeset(attrs)
      |> Repo.account_repo().update()
    else
      true ->
        {:error, %{reason: :item_not_found}}
    end
  end

  def get_max_watchlist_addresses_count,
    do: Application.get_env(:explorer, Explorer.Account)[:watchlist_addresses_limit]

  def preload_address_fetched_coin_balance(%Watchlist{watchlist_addresses: watchlist_addresses} = watchlist) do
    w_addresses =
      Enum.map(watchlist_addresses, fn wa ->
        preload_address_fetched_coin_balance(wa)
      end)

    %Watchlist{watchlist | watchlist_addresses: w_addresses}
  end

  def preload_address_fetched_coin_balance(%__MODULE__{address_hash: address_hash} = watchlist_address) do
    %__MODULE__{watchlist_address | fetched_coin_balance: address_hash |> Address.fetched_coin_balance() |> Repo.one()}
  end

  def preload_address_fetched_coin_balance(watchlist), do: watchlist
end
