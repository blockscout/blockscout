defmodule Explorer.Chain.CeloEpochRewards do
  @moduledoc """
  Datatype for storing Celo epoch rewards
  """

  require Logger

  use Explorer.Schema

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.{Block, Hash, Wei}
  alias Explorer.Repo

  @typedoc """
  * `block_hash` - block where this reward was paid.
  """

  @type t :: %__MODULE__{
          block_hash: Hash.Full.t(),
          block_number: non_neg_integer(),
          epoch_number: non_neg_integer(),
          validator_target_epoch_rewards: Wei.t(),
          voter_target_epoch_rewards: Wei.t(),
          community_target_epoch_rewards: Wei.t(),
          carbon_offsetting_target_epoch_rewards: Wei.t(),
          target_total_supply: Wei.t(),
          rewards_multiplier: float(),
          rewards_multiplier_max: float(),
          rewards_multiplier_under: float(),
          rewards_multiplier_over: float(),
          target_voting_yield: float(),
          target_voting_yield_max: float(),
          target_voting_yield_adjustment_factor: float(),
          target_voting_fraction: float(),
          voting_fraction: float(),
          total_locked_gold: Wei.t(),
          total_non_voting: Wei.t(),
          total_votes: Wei.t(),
          electable_validators_max: non_neg_integer(),
          reserve_gold_balance: Wei.t(),
          gold_total_supply: Wei.t(),
          stable_usd_total_supply: Wei.t()
        }

  @attrs ~w( block_hash block_number epoch_number validator_target_epoch_rewards voter_target_epoch_rewards community_target_epoch_rewards carbon_offsetting_target_epoch_rewards target_total_supply rewards_multiplier rewards_multiplier_max rewards_multiplier_under rewards_multiplier_over target_voting_yield target_voting_yield_max target_voting_yield_adjustment_factor target_voting_fraction voting_fraction total_locked_gold total_non_voting total_votes electable_validators_max reserve_gold_balance gold_total_supply stable_usd_total_supply )a

  @required_attrs ~w( block_hash )a

  schema "celo_epoch_rewards" do
    field(:block_number, :integer)
    field(:epoch_number, :integer)
    field(:validator_target_epoch_rewards, Wei)
    field(:voter_target_epoch_rewards, Wei)
    field(:community_target_epoch_rewards, Wei)
    field(:carbon_offsetting_target_epoch_rewards, Wei)
    field(:target_total_supply, Wei)
    field(:rewards_multiplier, :decimal)
    field(:rewards_multiplier_max, :decimal)
    field(:rewards_multiplier_under, :decimal)
    field(:rewards_multiplier_over, :decimal)
    field(:target_voting_yield, :decimal)
    field(:target_voting_yield_max, :decimal)
    field(:target_voting_yield_adjustment_factor, :decimal)
    field(:target_voting_fraction, :decimal)
    field(:voting_fraction, :decimal)
    field(:total_locked_gold, Wei)
    field(:total_non_voting, Wei)
    field(:total_votes, Wei)
    field(:electable_validators_max, :integer)
    field(:reserve_gold_balance, Wei)
    field(:gold_total_supply, Wei)
    field(:stable_usd_total_supply, Wei)

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = item, attrs) do
    item
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:celo_epoch_rewards_key, name: :celo_epoch_rewards_block_hash_index)
  end

  def get_celo_epoch_rewards_for_block(block_number) do
    Repo.one(from(rewards in __MODULE__, where: rewards.block_number == ^block_number))
  end
end
