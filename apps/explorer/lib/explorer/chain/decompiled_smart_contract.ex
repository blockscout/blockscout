defmodule Explorer.Chain.DecompiledSmartContract do
  @moduledoc """
  The representation of a decompiled smart contract.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}

  @derive {Jason.Encoder, only: [:address_hash, :decompiler_version, :decompiled_source_code]}

  schema "decompiled_smart_contracts" do
    field(:decompiler_version, :string)
    field(:decompiled_source_code, :string)

    belongs_to(
      :address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = smart_contract, attrs) do
    smart_contract
    |> cast(attrs, [:decompiler_version, :decompiled_source_code, :address_hash])
    |> validate_required([:decompiler_version, :decompiled_source_code, :address_hash])
    |> unique_constraint(:address_hash)
  end
end
