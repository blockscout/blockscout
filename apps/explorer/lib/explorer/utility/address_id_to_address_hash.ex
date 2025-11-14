defmodule Explorer.Utility.AddressIdToAddressHash do
  @moduledoc """
  Module is responsible for keeping the address_id to address_hash correspondence.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

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
end
