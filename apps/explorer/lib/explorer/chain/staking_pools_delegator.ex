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
    StakingPool,
    Wei
  }

  @type t :: %__MODULE__{
          pool_address_hash: Hash.Address.t(),
          delegator_address_hash: Hash.Address.t(),
          max_ordered_withdraw_allowed: Wei.t(),
          max_withdraw_allowed: Wei.t(),
          ordered_withdraw: Wei.t(),
          stake_amount: Wei.t(),
          ordered_withdraw_epoch: integer()
        }

  @attrs ~w(
    pool_address_hash delegator_address_hash max_ordered_withdraw_allowed
    max_withdraw_allowed ordered_withdraw stake_amount ordered_withdraw_epoch
  )a

  schema "staking_pools_delegators" do
    field(:max_ordered_withdraw_allowed, Wei)
    field(:max_withdraw_allowed, Wei)
    field(:ordered_withdraw, Wei)
    field(:ordered_withdraw_epoch, :integer)
    field(:stake_amount, Wei)

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
    |> validate_required(@attrs)
    |> unique_constraint(:pool_address_hash, name: :pools_delegator_index)
  end
end
