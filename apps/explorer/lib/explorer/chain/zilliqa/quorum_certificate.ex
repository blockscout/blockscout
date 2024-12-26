defmodule Explorer.Chain.Zilliqa.QuorumCertificate do
  @moduledoc """
  A stored representation of a Zilliqa quorum certificate in the context of PBFT
  consensus.

  In PBFT (Practical Byzantine Fault Tolerance) consensus, a quorum certificate
  is a data structure that serves as proof that a block has been approved by a
  supermajority of validators. It includes aggregated signatures and a bitmap
  indicating which validators participated in the consensus.

  Changes in the schema should be reflected in the bulk import module:
  - `Explorer.Chain.Import.Runner.Zilliqa.AggregateQuorumCertificate`
  """
  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.Zilliqa.Hash.Signature, as: SignatureHash

  @required_attrs ~w(block_hash view signature signers)a

  @typedoc """
  * `view` - the view number associated with the quorum certificate, indicating
    the consensus round.
  * `signature` - the aggregated BLS (Boneh–Lynn–Shacham) signature representing
    the validators' agreement.
  * `signers` - the array of integers representing the indices of validators who
    participated in the quorum (as indicated by the `cosigned` bit vector).
  * `block_hash` - the hash of the block associated with this quorum
    certificate.
  """
  @primary_key false
  typed_schema "zilliqa_quorum_certificates" do
    field(:view, :integer)
    field(:signature, SignatureHash)
    field(:signers, {:array, :integer})

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = cert, attrs) do
    cert
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash, name: :quorum_certificates_pkey)
  end
end
