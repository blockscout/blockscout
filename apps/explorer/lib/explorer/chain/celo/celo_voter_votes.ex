defmodule Explorer.Chain.CeloVoterVotes do
  @moduledoc """
  Tracks individual active votes for every voter on each epoch.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash, Wei}
  alias Explorer.Repo

  @required_attrs ~w(account_hash block_hash block_number active_votes group_hash)a

  @typedoc """
   * `account_hash` - the hash of the voter's account.
   * `active_votes` - the number of the voter's active votes for a specific group.
   * `block_hash` - the hash of the block.
   * `block_number` - the number of the block.
   * `group_hash` - the hash of the group.
  """
  @type t :: %__MODULE__{
          account_hash: Hash.Address.t(),
          active_votes: Wei.t(),
          block_hash: Hash.Full.t(),
          block_number: integer,
          group_hash: Hash.Address.t()
        }

  @primary_key false
  schema "celo_voter_votes" do
    field(:active_votes, Wei)
    field(:block_number, :integer)
    field(:group_hash, Hash.Address)

    timestamps()

    belongs_to(:block, Block, foreign_key: :block_hash, primary_key: true, references: :hash, type: Hash.Full)

    belongs_to(:addresses, Explorer.Chain.Address,
      foreign_key: :account_hash,
      references: :hash,
      type: Hash.Address
    )
  end

  def changeset(%__MODULE__{} = celo_voter_votes, attrs) do
    celo_voter_votes
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> foreign_key_constraint(:group_hash)
    |> foreign_key_constraint(:account_hash)
    |> unique_constraint(
      [:account_hash, :block_hash, :group_hash],
      name: :celo_voter_votes_account_hash_block_hash_group_hash_index
    )
  end

  def previous_epoch_non_zero_voter_votes(epoch_block_number) do
    zero_votes = %Explorer.Chain.Wei{value: Decimal.new(0)}
    previous_epoch_block_number = epoch_block_number - 17_280

    query =
      from(
        votes in __MODULE__,
        where: votes.block_number == ^previous_epoch_block_number,
        where: votes.active_votes != ^zero_votes,
        select: %{
          account_hash: votes.account_hash,
          group_hash: votes.group_hash
        }
      )

    query
    |> Repo.all()
  end
end
