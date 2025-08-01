defmodule Explorer.Chain.Zilliqa.NestedQuorumCertificate do
  @moduledoc """
  A stored representation of a nested quorum certificate in Zilliqa's PBFT
  consensus.

  In Zilliqa's PBFT (Practical Byzantine Fault Tolerance) consensus, an
  aggregate quorum certificate may include multiple nested quorum certificates.
  Each nested quorum certificate represents a quorum certificate proposed by a
  specific validator and contains its own aggregated signatures and participant
  information.

  Changes in the schema should be reflected in the bulk import module:
  - `Explorer.Chain.Import.Runner.Zilliqa.AggregateQuorumCertificate`
  """
  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Zilliqa.AggregateQuorumCertificate
  alias Explorer.Chain.Zilliqa.Hash.Signature, as: SignatureHash

  @required_attrs ~w(block_hash proposed_by_validator_index view signature signers)a

  @typedoc """
  * `proposed_by_validator_index` - the index of the validator who proposed this
    nested quorum certificate.
  * `view` - the view number associated with the quorum certificate, indicating
    the consensus round.
  * `signature` - the aggregated BLS (Boneh–Lynn–Shacham) signature representing
    the validators' agreement.
  * `signers` - the array of integers representing the indices of validators who
    participated in the quorum (as indicated by the `cosigned` bit vector).
  * `block_hash` - the hash of the block associated with the aggregate quorum
    certificate to which this nested quorum certificate belongs.
  """
  @primary_key false
  typed_schema "zilliqa_nested_quorum_certificates" do
    field(:proposed_by_validator_index, :integer, primary_key: true)
    field(:view, :integer)
    field(:signature, SignatureHash)
    field(:signers, {:array, :integer})

    belongs_to(:aggregate_quorum_certificate, AggregateQuorumCertificate,
      foreign_key: :block_hash,
      references: :block_hash,
      primary_key: true,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = cert, attrs) do
    cert
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(
      [:proposed_by_validator_index, :block_hash],
      name: :nested_quorum_certificates_pkey
    )
  end
end
