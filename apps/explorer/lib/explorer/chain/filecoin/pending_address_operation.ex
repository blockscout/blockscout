defmodule Explorer.Chain.Filecoin.PendingAddressOperation do
  @moduledoc """
  Tracks an address that is pending for fetching of filecoin address info.
  """

  use Explorer.Schema

  import Explorer.Chain, only: [add_fetcher_limit: 2]
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo

  @required_attrs ~w(address_hash)a
  @optional_attrs ~w(refetch_after)a

  @attrs @optional_attrs ++ @required_attrs

  @typedoc """
   * `address_hash` - the hash of the address that is pending to be fetched.
   * `refetch_after` - the time when the address should be refetched.
  """
  @primary_key false
  typed_schema "filecoin_pending_address_operations" do
    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address,
      primary_key: true
    )

    field(:refetch_after, :utc_datetime_usec)

    timestamps()
  end

  @spec changeset(
          t(),
          :invalid | %{optional(:__struct__) => none(), optional(atom() | binary()) => any()}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:address_hash, name: :filecoin_pending_address_operations_address_hash_fkey)
    |> unique_constraint(:address_hash, name: :filecoin_pending_address_operations_pkey)
  end

  @doc """
  Returns a query for pending operations that have never been fetched.
  """
  @spec fresh_operations_query() :: Ecto.Query.t()
  def fresh_operations_query do
    from(p in __MODULE__, where: is_nil(p.refetch_after))
  end

  @doc """
  Checks if a pending operation exists for a given address hash.
  """
  @spec exists?(t()) :: boolean()
  def exists?(%__MODULE__{address_hash: address_hash}) do
    query =
      from(
        op in __MODULE__,
        where: op.address_hash == ^address_hash
      )

    Repo.exists?(query)
  end

  @doc """
  Returns a stream of pending operations.
  """
  @spec stream(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    fresh_operations_query()
    |> order_by([op], desc: op.address_hash)
    |> add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end
end
