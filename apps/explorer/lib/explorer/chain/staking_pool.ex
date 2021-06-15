defmodule Explorer.Chain.StakingPool do
  @moduledoc """
  The representation of staking pool from POSDAO network.
  Staking pools might be candidate or validator.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Explorer.Chain.{
    Address,
    Hash,
    StakingPoolsDelegator
  }

  @type t :: %__MODULE__{
          are_delegators_banned: boolean,
          banned_delegators_until: integer,
          banned_until: integer,
          ban_reason: String.t(),
          delegators_count: integer,
          is_active: boolean,
          is_banned: boolean,
          is_deleted: boolean,
          is_unremovable: boolean,
          is_validator: boolean,
          likelihood: Decimal.t(),
          mining_address_hash: Hash.Address.t(),
          self_staked_amount: Decimal.t(),
          snapshotted_self_staked_amount: Decimal.t(),
          snapshotted_total_staked_amount: Decimal.t(),
          snapshotted_validator_reward_ratio: Decimal.t(),
          stakes_ratio: Decimal.t(),
          staking_address_hash: Hash.Address.t(),
          total_staked_amount: Decimal.t(),
          validator_reward_percent: Decimal.t(),
          validator_reward_ratio: Decimal.t(),
          was_banned_count: integer,
          was_validator_count: integer
        }

  @attrs ~w(
    are_delegators_banned
    banned_delegators_until
    banned_until
    ban_reason
    delegators_count
    is_active
    is_banned
    is_unremovable
    is_validator
    likelihood
    mining_address_hash
    self_staked_amount
    snapshotted_self_staked_amount
    snapshotted_total_staked_amount
    snapshotted_validator_reward_ratio
    stakes_ratio
    staking_address_hash
    total_staked_amount
    validator_reward_percent
    validator_reward_ratio
    was_banned_count
    was_validator_count
  )a
  @req_attrs ~w(
    banned_until
    delegators_count
    is_active
    is_banned
    is_unremovable
    is_validator
    mining_address_hash
    self_staked_amount
    staking_address_hash
    total_staked_amount
    was_banned_count
    was_validator_count
  )a

  schema "staking_pools" do
    field(:are_delegators_banned, :boolean, default: false)
    field(:banned_delegators_until, :integer)
    field(:banned_until, :integer)
    field(:ban_reason, :string)
    field(:delegators_count, :integer)
    field(:is_active, :boolean, default: false)
    field(:is_banned, :boolean, default: false)
    field(:is_deleted, :boolean, default: false)
    field(:is_unremovable, :boolean, default: false)
    field(:is_validator, :boolean, default: false)
    field(:likelihood, :decimal)
    field(:self_staked_amount, :decimal)
    field(:stakes_ratio, :decimal)
    field(:snapshotted_self_staked_amount, :decimal)
    field(:snapshotted_total_staked_amount, :decimal)
    field(:snapshotted_validator_reward_ratio, :decimal)
    field(:total_staked_amount, :decimal)
    field(:validator_reward_percent, :decimal)
    field(:validator_reward_ratio, :decimal)
    field(:was_banned_count, :integer)
    field(:was_validator_count, :integer)
    has_many(:delegators, StakingPoolsDelegator, foreign_key: :staking_address_hash)

    belongs_to(
      :staking_address,
      Address,
      foreign_key: :staking_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :mining_address,
      Address,
      foreign_key: :mining_address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(staking_pool, attrs) do
    staking_pool
    |> cast(attrs, @attrs)
    |> cast_assoc(:delegators)
    |> validate_required(@req_attrs)
    |> validate_staked_amount()
    |> unique_constraint(:staking_address_hash)
  end

  defp validate_staked_amount(%{valid?: false} = c), do: c

  defp validate_staked_amount(changeset) do
    if get_field(changeset, :total_staked_amount) < get_field(changeset, :self_staked_amount) do
      add_error(changeset, :total_staked_amount, "must be greater or equal to self_staked_amount")
    else
      changeset
    end
  end
end
