defmodule Explorer.Chain.AddressCounter do
  @moduledoc """
  Stores counters related to the address.
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @optional_attrs ~w(token_holders_count)a
  @required_attrs ~w(hash)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  Hash of the public key for this address.
  """
  @type hash :: Hash.t()

  @typedoc """
   * `hash` - the hash of the address's public key
   * `token_holders_count` - counter of holders of the related to this address token
  """
  @primary_key false
  typed_schema "address_counters" do
    field(:hash, Hash.Address, primary_key: true)
    field(:token_holders_count, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end

  @doc """
    Insert a new address counter to DB.
  """
  @spec create(map()) :: {:ok, __MODULE__.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    changeset =
      %__MODULE__{}
      |> changeset(attrs)

    Repo.insert(changeset,
      on_conflict: address_counter_on_conflict(),
      conflict_target: [:hash]
    )
  end

  @date_time_fields [:inserted_at, :updated_at]

  @spec get_value(Hash.Address.t(), atom()) :: non_neg_integer()
  def get_value(address_hash, field) do
    value =
      __MODULE__
      |> where(hash: ^address_hash)
      |> Repo.one()

    if field in @date_time_fields do
      value |> Map.get(field) |> DateTime.to_unix()
    else
      Map.get(value, field)
    end
  end

  defp address_counter_on_conflict do
    from(
      address_counter in __MODULE__,
      update: [
        set: [
          token_holders_count: fragment("EXCLUDED.token_holders_count"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", address_counter.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", address_counter.updated_at)
        ]
      ]
    )
  end
end
