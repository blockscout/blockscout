defmodule Explorer.Chain.Zilliqa.Zrc2.TokenAdapter do
  @moduledoc """
  Represents a list of `ERC-20 adapter contract address <-> ZRC-2 token contract address` pairs.

  Changes in the schema should be reflected in the bulk import module:
  - `Explorer.Chain.Import.Runner.Zilliqa.Zrc2.TokenAdapters`
  """
  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Repo

  @required_attrs ~w(zrc2_address_hash adapter_address_hash)a

  @typedoc """
  * `zrc2_address_hash` - The ZRC-2 token contract address hash.
  * `zrc2_address` - An instance of `Explorer.Chain.Address` referenced by `zrc2_address_hash`.
  * `adapter_address_hash` - The ERC-20 adapter contract address hash.
  * `adapter_address` - An instance of `Explorer.Chain.Address` referenced by `adapter_address_hash`.
  """
  @primary_key false
  typed_schema "zrc2_token_adapters" do
    belongs_to(:zrc2_address, Address,
      foreign_key: :zrc2_address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(:adapter_address, Address,
      foreign_key: :adapter_address_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = pair, attrs) do
    pair
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:zrc2_address_hash)
    |> foreign_key_constraint(:adapter_address_hash)
    |> unique_constraint(:adapter_address_hash)
  end

  @spec adapter_address_hash_by_zrc2_address_hash([Hash.t()]) :: %{Hash.t() => Hash.t()}
  def adapter_address_hash_by_zrc2_address_hash([]), do: %{}

  def adapter_address_hash_by_zrc2_address_hash(zrc2_address_hashes) do
    query =
      from(a in __MODULE__,
        select: {a.zrc2_address_hash, a.adapter_address_hash},
        where: a.zrc2_address_hash in ^zrc2_address_hashes
      )

    query
    |> Repo.all(timeout: :infinity)
    |> Enum.into(%{})
  end
end
