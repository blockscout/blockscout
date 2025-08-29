defmodule Explorer.Chain.Celo.PendingAccountOperation do
  @moduledoc """
  Tracks an address that is pending for fetching of celo account info.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}

  @required_attrs ~w(address_hash)a
  @allowed_attrs @required_attrs

  @typedoc """
   * `address_hash` - the hash of the address that is pending to be fetched.
  """
  @primary_key false
  typed_schema "celo_pending_account_operations" do
    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address,
      primary_key: true
    )

    timestamps()
  end

  @spec changeset(
          t(),
          :invalid | %{optional(:__struct__) => none(), optional(atom() | binary()) => any()}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:address_hash, name: :celo_pending_account_operations_address_hash_fkey)
    |> unique_constraint(:address_hash, name: :celo_pending_account_operations_pkey)
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
    __MODULE__
    |> order_by([op], desc: op.address_hash)
    |> Chain.add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @doc """
  Deletes pending operations by address hashes.
  """
  @spec delete_by_address_hashes([Hash.Address.t()]) :: {integer, nil | [term()]}
  def delete_by_address_hashes(address_hashes) do
    query =
      from(p in __MODULE__,
        where: p.address_hash in ^address_hashes
      )

    Repo.delete_all(query)
  end
end
