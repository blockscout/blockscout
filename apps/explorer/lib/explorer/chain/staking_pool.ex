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
          staking_address_hash: Hash.Address.t(),
          mining_address_hash: Hash.Address.t(),
          banned_until: integer,
          banned_delegators_until: integer,
          delegators_count: integer,
          is_active: boolean,
          is_banned: boolean,
          is_validator: boolean,
          is_unremovable: boolean,
          are_delegators_banned: boolean,
          likelihood: Decimal.t(),
          block_reward_ratio: Decimal.t(),
          stakes_ratio: Decimal.t(),
          validator_reward_ratio: Decimal.t(),
          snapshotted_validator_reward_ratio: Decimal.t(),
          self_staked_amount: Decimal.t(),
          total_staked_amount: Decimal.t(),
          snapshotted_self_staked_amount: Decimal.t(),
          snapshotted_total_staked_amount: Decimal.t(),
          ban_reason: String.t(),
          was_banned_count: integer,
          was_validator_count: integer,
          is_deleted: boolean
        }

  @attrs ~w(
    is_active delegators_count total_staked_amount self_staked_amount snapshotted_total_staked_amount snapshotted_self_staked_amount is_validator
    was_validator_count is_banned are_delegators_banned ban_reason was_banned_count banned_until banned_delegators_until likelihood
    stakes_ratio validator_reward_ratio snapshotted_validator_reward_ratio staking_address_hash mining_address_hash block_reward_ratio
    is_unremovable
  )a
  @req_attrs ~w(
    is_active delegators_count total_staked_amount self_staked_amount is_validator
    was_validator_count is_banned was_banned_count banned_until
    staking_address_hash mining_address_hash is_unremovable
  )a

  schema "staking_pools" do
    field(:banned_until, :integer)
    field(:banned_delegators_until, :integer)
    field(:delegators_count, :integer)
    field(:is_active, :boolean, default: false)
    field(:is_banned, :boolean, default: false)
    field(:is_validator, :boolean, default: false)
    field(:is_unremovable, :boolean, default: false)
    field(:are_delegators_banned, :boolean, default: false)
    field(:likelihood, :decimal)
    field(:block_reward_ratio, :decimal)
    field(:stakes_ratio, :decimal)
    field(:validator_reward_ratio, :decimal)
    field(:snapshotted_validator_reward_ratio, :decimal)
    field(:self_staked_amount, :decimal)
    field(:total_staked_amount, :decimal)
    field(:snapshotted_self_staked_amount, :decimal)
    field(:snapshotted_total_staked_amount, :decimal)
    field(:ban_reason, :string)
    field(:was_banned_count, :integer)
    field(:was_validator_count, :integer)
    field(:is_deleted, :boolean, default: false)
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
      add_error(changeset, :total_staked_amount, "must be greater than self_staked_amount")
    else
      changeset
    end
  end
end
