defmodule Explorer.Chain.Beacon.Blob do
  @moduledoc "Models a data blob broadcasted using eip4844 blob transactions."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(hash blob_data kzg_commitment kzg_proof)a

  @type t :: %__MODULE__{
          hash: Hash.t(),
          blob_data: binary(),
          kzg_commitment: binary(),
          kzg_proof: binary()
        }

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "beacon_blobs" do
    field(:blob_data, :binary)
    field(:kzg_commitment, :binary)
    field(:kzg_proof, :binary)

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
