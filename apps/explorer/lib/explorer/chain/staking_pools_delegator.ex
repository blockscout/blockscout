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
          pool_address_hash: Hash.Address.t(),
          delegator_address_hash: Hash.Address.t(),
          max_ordered_withdraw_allowed: Decimal.t(),
          max_withdraw_allowed: Decimal.t(),
          ordered_withdraw: Decimal.t(),
          stake_amount: Decimal.t(),
          ordered_withdraw_epoch: integer(),
          is_active: boolean(),
          is_deleted: boolean()
        }

  @attrs ~w(
    pool_address_hash delegator_address_hash max_ordered_withdraw_allowed
    max_withdraw_allowed ordered_withdraw stake_amount ordered_withdraw_epoch
    is_active is_deleted
  )a

  @req_attrs ~w(
    pool_address_hash delegator_address_hash max_ordered_withdraw_allowed
    max_withdraw_allowed ordered_withdraw stake_amount ordered_withdraw_epoch

  )a

  schema "staking_pools_delegators" do
    field(:max_ordered_withdraw_allowed, :decimal)
    field(:max_withdraw_allowed, :decimal)
    field(:ordered_withdraw, :decimal)
    field(:ordered_withdraw_epoch, :integer)
    field(:stake_amount, :decimal)
    field(:is_active, :boolean, default: true)
    field(:is_deleted, :boolean, default: false)

    belongs_to(
      :staking_pool,
      StakingPool,
      foreign_key: :pool_address_hash,
      references: :staking_address_hash,
      type: Hash.Address
    )

    belongs_to(
      :delegator_address,
      Address,
      foreign_key: :delegator_address_hash,
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
    |> unique_constraint(:pool_address_hash, name: :pools_delegator_index)
  end
end
