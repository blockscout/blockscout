defmodule Explorer.Chain.Filecoin.PendingAddressOperation do
  @moduledoc """
  Tracks an address that is pending for fetching of filecoin address info.
  """

  use Explorer.Schema

  import Explorer.Chain, only: [add_fetcher_limit: 2]
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo

  @http_error_codes 400..526

  @optional_attrs ~w(http_status_code)a
  @required_attrs ~w(address_hash)a

  @attrs @optional_attrs ++ @required_attrs

  @typedoc """
   * `address_hash` - the hash of the address that is pending to be fetched.
   * `http_status_code` - the unsuccessful (non-200) http code returned by Beryx
     API if the fetcher failed to fetch the address.
  """
  @primary_key false
  typed_schema "filecoin_pending_address_operations" do
    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address,
      primary_key: true
    )

    field(:http_status_code, :integer)

    timestamps()
  end

  @spec changeset(
          Explorer.Chain.Filecoin.PendingAddressOperation.t(),
          :invalid | %{optional(:__struct__) => none(), optional(atom() | binary()) => any()}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:address_hash, name: :filecoin_pending_address_operations_address_hash_fkey)
    |> unique_constraint(:address_hash, name: :filecoin_pending_address_operations_pkey)
    |> validate_inclusion(:http_status_code, @http_error_codes)
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
