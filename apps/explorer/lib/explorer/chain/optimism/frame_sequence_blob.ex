defmodule Explorer.Chain.Optimism.FrameSequenceBlob do
  @moduledoc """
    Models a blob related to Optimism frame sequence.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Optimism.FrameSequenceBlobs

    Migrations:
    - Explorer.Repo.Optimism.Migrations.AddCelestiaBlobMetadata
  """

  use Explorer.Schema

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Optimism.FrameSequence

  @required_attrs ~w(id key type metadata l1_transaction_hash l1_timestamp frame_sequence_id)a

  @type t :: %__MODULE__{
          key: binary(),
          type: String.t(),
          metadata: map(),
          l1_transaction_hash: Hash.t(),
          l1_timestamp: DateTime.t(),
          frame_sequence_id: non_neg_integer(),
          frame_sequence: %Ecto.Association.NotLoaded{} | FrameSequence.t()
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "op_frame_sequence_blobs" do
    field(:key, :binary)
    field(:type, Ecto.Enum, values: [:celestia, :eip4844])
    field(:metadata, :map)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_timestamp, :utc_datetime_usec)
    belongs_to(:frame_sequence, FrameSequence, foreign_key: :frame_sequence_id, references: :id, type: :integer)
    timestamps()
  end

  @doc """
    Validates that the attributes are valid.
  """
  def changeset(%__MODULE__{} = blobs, attrs \\ %{}) do
    blobs
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
    |> unique_constraint([:key, :type])
    |> foreign_key_constraint(:frame_sequence_id)
  end

  @doc """
    Lists `t:Explorer.Chain.Optimism.FrameSequenceBlob.t/0`'s' related to the
    specified frame sequence in ascending order based on an entity id.

    ## Parameters
    - `frame_sequence_id`: A frame sequence identifier.
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - A tuple {type, blobs} where `type` can be one of: `in_blob4844`, `in_celestia`, `in_calldata`.
      The `blobs` in the list of blobs related to the specified frame sequence id sorted by an entity id.
  """
  @spec list(non_neg_integer(), list()) :: {:in_blob4844 | :in_celestia | :in_calldata, [map()]}
  def list(frame_sequence_id, options \\ []) do
    repo = select_repo(options)

    query =
      from(fsb in __MODULE__,
        where: fsb.frame_sequence_id == ^frame_sequence_id,
        order_by: [asc: fsb.id]
      )

    query
    |> repo.all()
    |> filter_blobs_by_type()
  end

  defp filter_blobs_by_type(blobs) do
    eip4844_blobs =
      blobs
      |> Enum.filter(fn b -> b.type == :eip4844 end)
      |> Enum.map(fn b ->
        %{
          "hash" => b.metadata["hash"],
          "l1_transaction_hash" => b.l1_transaction_hash,
          "l1_timestamp" => b.l1_timestamp
        }
      end)

    celestia_blobs =
      blobs
      |> Enum.filter(fn b -> b.type == :celestia end)
      |> Enum.map(fn b ->
        %{
          "height" => b.metadata["height"],
          "namespace" => b.metadata["namespace"],
          "commitment" => b.metadata["commitment"],
          "l1_transaction_hash" => b.l1_transaction_hash,
          "l1_timestamp" => b.l1_timestamp
        }
      end)

    cond do
      not Enum.empty?(eip4844_blobs) ->
        {:in_blob4844, eip4844_blobs}

      not Enum.empty?(celestia_blobs) ->
        {:in_celestia, celestia_blobs}

      true ->
        {:in_calldata, []}
    end
  end
end
