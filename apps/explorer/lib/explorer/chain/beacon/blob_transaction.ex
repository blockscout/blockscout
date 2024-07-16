defmodule Explorer.Chain.Beacon.BlobTransaction do
  @moduledoc "Models a transaction extension with extra fields from eip4844 blob transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}

  @required_attrs ~w(hash max_fee_per_blob_gas blob_gas_price blob_gas_used blob_versioned_hashes)a

  @type t :: %__MODULE__{
          hash: Hash.t(),
          max_fee_per_blob_gas: Decimal.t(),
          blob_gas_price: Decimal.t(),
          blob_gas_used: Decimal.t(),
          blob_versioned_hashes: [Hash.t()]
        }

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "beacon_blobs_transactions" do
    field(:max_fee_per_blob_gas, :decimal)
    field(:blob_gas_price, :decimal)
    field(:blob_gas_used, :decimal)
    field(:blob_versioned_hashes, {:array, Hash.Full})

    belongs_to(:transaction, Transaction,
      foreign_key: :hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      define_field: false
    )

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:hash)
    |> unique_constraint(:hash)
  end
end
