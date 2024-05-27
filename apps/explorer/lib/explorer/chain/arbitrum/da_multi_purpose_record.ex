defmodule Explorer.Chain.Arbitrum.DaMultiPurposeRecord do
  @moduledoc """
    Models a multi purpose record related to Data Availability for Arbitrum.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.DAMultiPurposeRecords

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.AddDaInfo
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash

  alias Explorer.Chain.Arbitrum.L1Batch

  @optional_attrs ~w(batch_number)a

  @required_attrs ~w(data_key data_type data)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @type t :: %__MODULE__{
          data_key: Hash.t(),
          data_type: non_neg_integer(),
          data: map(),
          batch_number: non_neg_integer(),
          batch: %Ecto.Association.NotLoaded{} | L1Batch.t() | nil
        }

  @primary_key false
  schema "arbitrum_da_multi_purpose" do
    field(:data_key, Hash.Full)
    field(:data_type, :integer)
    field(:data, :map)

    belongs_to(:batch, L1Batch,
      foreign_key: :batch_number,
      references: :number,
      type: :integer
    )

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = da_records, attrs \\ %{}) do
    da_records
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:batch_number)
    |> unique_constraint(:data_key)
  end
end
