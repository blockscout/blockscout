defmodule Explorer.Chain.Zilliqa.AggregateQuorumCertificate do
  @moduledoc """
  A stored representation of a Zilliqa aggregate quorum certificate in the
  context of PBFT consensus.

  In PBFT (Practical Byzantine Fault Tolerance) consensus, an aggregate quorum
  certificate combines multiple quorum certificates into one, providing proof
  that a block has been approved across multiple consensus rounds or by multiple
  subsets of validators. It includes aggregated signatures and references to
  nested quorum certificates.

  Changes in the schema should be reflected in the bulk import module:
  - `Explorer.Chain.Import.Runner.Zilliqa.AggregateQuorumCertificate`
  """
  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.Zilliqa.Hash.Signature, as: SignatureHash
  alias Explorer.Chain.Zilliqa.NestedQuorumCertificate

  @required_attrs ~w(block_hash view signature)a

  @typedoc """
  * `view` - the view number associated with the quorum certificate, indicating
    the consensus round.
  * `signature` - the aggregated BLS (Boneh–Lynn–Shacham) signature representing
    the validators' agreement.
  * `block_hash` - the hash of the block associated with this aggregate quorum
    certificate.
  * `nested_quorum_certificates` - the list of nested quorum certificates that
    are part of this aggregate.
  """
  @primary_key false
  typed_schema "zilliqa_aggregate_quorum_certificates" do
    field(:view, :integer)
    field(:signature, SignatureHash)

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    has_many(
      :nested_quorum_certificates,
      NestedQuorumCertificate,
      foreign_key: :block_hash,
      references: :block_hash
    )

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = cert, attrs) do
    cert
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash, name: :aggregate_quorum_certificates_pkey)
  end
end
