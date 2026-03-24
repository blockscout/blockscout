defmodule Explorer.Utility.AddressIdToAddressHash do
  @moduledoc """
  Module is responsible for keeping the address_id to address_hash correspondence.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo

  @primary_key false
  typed_schema "address_ids_to_address_hashes" do
    field(:address_id, :integer, primary_key: true)

    belongs_to(:address, Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )
  end

  @doc false
  def changeset(address_id_to_address_hash \\ %__MODULE__{}, params) do
    cast(address_id_to_address_hash, params, [:address_id, :address_hash])
  end

  def find_or_create(address_hash) do
    [address_hash]
    |> find_or_create_multiple(false)
    |> List.first()
  end

  def find_or_create_multiple(address_hashes, to_map? \\ true) do
    filtered_address_hashes =
      address_hashes
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.map(fn address_hash ->
        {:ok, casted} = Hash.Address.cast(address_hash)
        casted
      end)

    Repo.insert_all(
      __MODULE__,
      Enum.map(filtered_address_hashes, &%{address_hash: &1}),
      on_conflict: :nothing
    )

    __MODULE__
    |> where([a], a.address_hash in ^filtered_address_hashes)
    |> Repo.all()
    |> then(fn records ->
      if to_map?, do: Map.new(records, &{&1.address_hash, &1.address_id}), else: records
    end)
  end

  @doc """
  Retrieves the address_id for a given address_hash.

  ## Parameters
  - `hash`: The address hash to look up

  ## Returns
  - The address_id if found, nil otherwise
  """
  @spec hash_to_id(Hash.Address.t()) :: integer() | nil
  def hash_to_id(nil), do: nil

  def hash_to_id(hash) do
    __MODULE__
    |> where([a], a.address_hash == ^hash)
    |> select([a], a.address_id)
    |> Repo.one()
  end

  def id_to_hash(nil), do: nil

  def id_to_hash(id) do
    [id]
    |> ids_to_hashes()
    |> List.first()
  end

  def ids_to_hashes([]), do: []

  def ids_to_hashes(ids) do
    __MODULE__
    |> where([a], a.address_id in ^ids)
    |> select([a], a.address_hash)
    |> Repo.all()
  end
end
