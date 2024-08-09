defmodule Explorer.Chain.Filecoin.PendingAddressOperation do
  @moduledoc """
  Tracks an address that is pending for fetching of filecoin native address.
  """

  use Explorer.Schema

  import Explorer.Chain, only: [add_fetcher_limit: 2]
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo

  @required_attrs ~w(address_hash)a

  @typedoc """
   * `address_hash` - the hash of the address that is pending to be fetched.
  """
  @primary_key false
  typed_schema "filecoin_pending_address_operations" do
    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address,
      primary_key: true
    )

    timestamps()
  end

  @spec changeset(
          Explorer.Chain.Filecoin.PendingAddressOperation.t(),
          :invalid | %{optional(:__struct__) => none(), optional(atom() | binary()) => any()}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:address_hash, name: :filecoin_pending_address_operations_address_hash_fkey)
    |> unique_constraint(:address_hash, name: :filecoin_pending_address_operations_pkey)
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
    query =
      from(
        op in __MODULE__,
        select: op,
        order_by: [desc: op.address_hash]
      )

    query
    |> add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end
end
