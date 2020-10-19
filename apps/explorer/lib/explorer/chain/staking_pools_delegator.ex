defmodule Explorer.Chain.StakingPoolsDelegator do
  @moduledoc """
  The representation of delegators from POSDAO network.
  Delegators make stakes on staking pools and withdraw from them.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Explorer.Chain.{
    Address,
    Hash,
    StakingPool
  }

  @type t :: %__MODULE__{
          address_hash: Hash.Address.t(),
          is_active: boolean(),
          is_deleted: boolean(),
          max_ordered_withdraw_allowed: Decimal.t(),
          max_withdraw_allowed: Decimal.t(),
          ordered_withdraw: Decimal.t(),
          ordered_withdraw_epoch: integer(),
          reward_ratio: Decimal.t(),
          snapshotted_reward_ratio: Decimal.t(),
          snapshotted_stake_amount: Decimal.t(),
          stake_amount: Decimal.t(),
          staking_address_hash: Hash.Address.t()
        }

  @attrs ~w(
    address_hash
    is_active
    is_deleted
    max_ordered_withdraw_allowed
    max_withdraw_allowed
    ordered_withdraw
    ordered_withdraw_epoch
    reward_ratio
    snapshotted_reward_ratio
    snapshotted_stake_amount
    stake_amount
    staking_address_hash
  )a

  @req_attrs ~w(
    address_hash
    max_ordered_withdraw_allowed
    max_withdraw_allowed
    ordered_withdraw
    ordered_withdraw_epoch
    stake_amount
    staking_address_hash
  )a

  schema "staking_pools_delegators" do
    field(:is_active, :boolean, default: true)
    field(:is_deleted, :boolean, default: false)
    field(:max_ordered_withdraw_allowed, :decimal)
    field(:max_withdraw_allowed, :decimal)
    field(:ordered_withdraw, :decimal)
    field(:ordered_withdraw_epoch, :integer)
    field(:reward_ratio, :decimal)
    field(:snapshotted_reward_ratio, :decimal)
    field(:snapshotted_stake_amount, :decimal)
    field(:stake_amount, :decimal)

    belongs_to(
      :staking_pool,
      StakingPool,
      foreign_key: :staking_address_hash,
      references: :staking_address_hash,
      type: Hash.Address
    )

    belongs_to(
      :delegator_address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps(null: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(staking_pools_delegator, attrs) do
    staking_pools_delegator
    |> cast(attrs, @attrs)
    |> validate_required(@req_attrs)
    |> unique_constraint(:staking_address_hash, name: :pools_delegator_index)
  end
end
