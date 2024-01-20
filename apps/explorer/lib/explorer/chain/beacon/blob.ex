defmodule Explorer.Chain.Beacon.Blob do
  @moduledoc "Models a data blob broadcasted using eip4844 blob transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Data, Hash}

  @required_attrs ~w(hash blob_data kzg_commitment kzg_proof)a

  @type t :: %__MODULE__{
          hash: Hash.t(),
          blob_data: Data.t(),
          kzg_commitment: Data.t(),
          kzg_proof: Data.t()
        }

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "beacon_blobs" do
    field(:blob_data, Data)
    field(:kzg_commitment, Data)
    field(:kzg_proof, Data)

    timestamps(updated_at: false)
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end
end
