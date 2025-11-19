defmodule Explorer.Chain.Zilliqa.Zrc2.TokenAdapter do
  @moduledoc """
  Represents a list of `ERC-20 adapter contract address <-> ZRC-2 token contract address` pairs.

  Changes in the schema should be reflected in the bulk import module:
  - `Explorer.Chain.Import.Runner.Zilliqa.Zrc2.TokenAdapters`
  """
  use Explorer.Schema

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}

  @required_attrs ~w(zrc2_address_hash adapter_address_hash)a

  @typedoc """
  * `zrc2_address_hash` - The ZRC-2 token contract address hash.
  * `zrc2_address` - An instance of `Explorer.Chain.Address` referenced by `zrc2_address_hash`.
  * `adapter_address_hash` - The ERC-20 adapter contract address hash.
  * `adapter_address` - An instance of `Explorer.Chain.Address` referenced by `adapter_address_hash`.
  """
  @primary_key false
  typed_schema "zilliqa_zrc2_token_adapters" do
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

  @doc """
  Builds `%{zrc2_address_hash => adapter_address_hash}` map for the given ZRC-2 address hashes.
  If adapter address is not found for some ZRC-2 address, the corresponding key will be absent in the map.

  ## Parameters
  - `zrc2_address_hashes`: The list of ZRC-2 address hashes.

  ## Returns
  - `%{zrc2_address_hash => adapter_address_hash}` map. The map can be empty.
  """
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

  @doc """
  Returns ZRC-2 address hash for the given adapter address hash.

  ## Parameters
  - `adapter_address_hash`: The adapter address hash.
  - `options`: A keyword list of options that may include whether to use a replica database.

  ## Returns
  - ZRC-2 address hash for the adapter address hash.
  - `nil` if the ZRC-2 address hash is not found.
  """
  @spec adapter_address_hash_to_zrc2_address_hash(Hash.t(), [Chain.api?()]) :: Hash.t() | nil
  def adapter_address_hash_to_zrc2_address_hash(adapter_address_hash, options \\ []) do
    query =
      from(a in __MODULE__,
        select: a.zrc2_address_hash,
        where: a.adapter_address_hash == ^adapter_address_hash
      )

    Chain.select_repo(options).one(query)
  end
end
