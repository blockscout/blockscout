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

  @typedoc """
  Descriptor of the multi purpose record related to Data Availability for Arbitrum rollups:
    * `data_key` - The hash of the data key.
    * `data_type` - The type of the data.
    * `data` - The data
    * `batch_number` - The number of the Arbitrum batch associated with the data for the
                       records where applicable.
  """
  @type to_import :: %{
          data_key: binary(),
          data_type: non_neg_integer(),
          data: map(),
          batch_number: non_neg_integer() | nil
        }

  @typedoc """
    * `data_key` - The hash of the data key.
    * `data_type` - The type of the data.
    * `data` - The data to be stored as a json in the database.
    * `batch_number` - The number of the Arbitrum batch associated with the data for the
                       records where applicable.
    * `batch` - An instance of `Explorer.Chain.Arbitrum.L1Batch` referenced by `batch_number`.
  """
  @primary_key false
  typed_schema "arbitrum_da_multi_purpose" do
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

defmodule Explorer.Chain.Arbitrum.DaMultiPurposeRecord.Helper do
  @moduledoc """
    Helper functions to work with `Explorer.Chain.Arbitrum.DaMultiPurposeRecord` data
  """

  alias Explorer.Chain.Hash

  @doc """
    Calculates the data key for `Explorer.Chain.Arbitrum.DaMultiPurposeRecord` that contains Celestia blob data.

    ## Parameters
    - `height`: The height of the block in the Celestia network.
    - `transaction_commitment`: The transaction commitment.

    ## Returns
    - A binary representing the calculated data key for the record containing
      Celestia blob data.
  """
  @spec calculate_celestia_data_key(binary() | non_neg_integer(), binary() | Explorer.Chain.Hash.t()) :: binary()
  def calculate_celestia_data_key(height, transaction_commitment) when is_binary(height) do
    calculate_celestia_data_key(String.to_integer(height), transaction_commitment)
  end

  def calculate_celestia_data_key(height, %Hash{} = transaction_commitment) when is_integer(height) do
    calculate_celestia_data_key(height, transaction_commitment.bytes)
  end

  def calculate_celestia_data_key(height, transaction_commitment)
      when is_integer(height) and is_binary(transaction_commitment) do
    :crypto.hash(:sha256, :binary.encode_unsigned(height) <> transaction_commitment)
  end
end
