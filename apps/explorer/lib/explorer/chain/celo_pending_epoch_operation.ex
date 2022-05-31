defmodule Explorer.Chain.CeloPendingEpochOperation do
  @moduledoc """
  Tracks epoch blocks that have pending operations.
  """

  use Explorer.Schema

  alias Explorer.Repo

  import Ecto.Query,
    only: [
      from: 2
    ]

  @required_attrs ~w(block_number fetch_epoch_rewards election_rewards)a

  @typedoc """
   * `block_number` - the number of the epoch block that has pending operations.
   * `fetch_epoch_rewards` - if the epoch rewards should be fetched (or not)
   * `election_rewards` - if the voter votes should be fetched (or not)
  """
  @type t :: %__MODULE__{
          block_number: non_neg_integer(),
          fetch_epoch_rewards: boolean(),
          election_rewards: boolean()
        }

  @primary_key {:block_number, :integer, autogenerate: false}
  schema "celo_pending_epoch_operations" do
    field(:fetch_epoch_rewards, :boolean)
    field(:election_rewards, :boolean)

    timestamps()
  end

  def changeset(%__MODULE__{} = celo_epoch_pending_ops, attrs) do
    celo_epoch_pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:block_number, name: :celo_pending_epoch_operations_pkey)
  end

  def default_on_conflict do
    from(
      celo_epoch_pending_ops in __MODULE__,
      update: [
        set: [
          fetch_epoch_rewards: celo_epoch_pending_ops.fetch_epoch_rewards or fragment("EXCLUDED.fetch_epoch_rewards"),
          election_rewards: celo_epoch_pending_ops.election_rewards or fragment("EXCLUDED.election_rewards"),
          # Don't update `block_number` as it is used for the conflict target
          inserted_at: celo_epoch_pending_ops.inserted_at,
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ],
      where: fragment("EXCLUDED.fetch_epoch_rewards <> ?", celo_epoch_pending_ops.fetch_epoch_rewards)
    )
  end

  @spec falsify_celo_pending_epoch_operation(
          non_neg_integer(),
          :fetch_epoch_rewards | :election_rewards | :fetch_validator_group_data | :fetch_voter_votes
        ) :: __MODULE__.t()
  def falsify_celo_pending_epoch_operation(block_number, operation_type) do
    celo_pending_operation = Repo.one(from(op in __MODULE__, where: op.block_number == ^block_number))

    new_celo_pending_operation = Map.put(celo_pending_operation, operation_type, false)

    %{
      fetch_epoch_rewards: new_fetch_epoch_rewards,
      election_rewards: new_election_rewards
    } = new_celo_pending_operation

    celo_pending_operation
    |> changeset(%{
      block_number: block_number,
      fetch_epoch_rewards: new_fetch_epoch_rewards,
      election_rewards: new_election_rewards
    })
    |> Repo.update()
  end
end
