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

  @doc """
  Retrieves the address_id for a given address_hash.

  ## Parameters
  - `hash`: The address hash to look up

  ## Returns
  - The address_id if found, nil otherwise
  """
  @spec hash_to_id(Hash.Address.t()) :: integer() | nil
  def hash_to_id(hash) do
    __MODULE__
    |> where([a], a.address_hash == ^hash)
    |> select([a], a.address_id)
    |> Repo.one()
  end
end
