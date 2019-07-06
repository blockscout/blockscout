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
    StakingPoolsDelegator,
    Wei
  }

  @type t :: %__MODULE__{
          staking_address_hash: Hash.Address.t(),
          mining_address_hash: Hash.Address.t(),
          banned_until: boolean,
          delegators_count: integer,
          is_active: boolean,
          is_banned: boolean,
          is_validator: boolean,
          likelihood: Decimal.t(),
          block_reward_ratio: Decimal.t(),
          staked_ratio: Decimal.t(),
          self_staked_amount: Wei.t(),
          staked_amount: Wei.t(),
          was_banned_count: integer,
          was_validator_count: integer,
          is_deleted: boolean
        }

  @attrs ~w(
    is_active delegators_count staked_amount self_staked_amount is_validator
    was_validator_count is_banned was_banned_count banned_until likelihood
    staked_ratio staking_address_hash mining_address_hash block_reward_ratio
  )a
  @req_attrs ~w(
    is_active delegators_count staked_amount self_staked_amount is_validator
    was_validator_count is_banned was_banned_count banned_until
    staking_address_hash mining_address_hash
  )a

  schema "staking_pools" do
    field(:banned_until, :integer)
    field(:delegators_count, :integer)
    field(:is_active, :boolean, default: false)
    field(:is_banned, :boolean, default: false)
    field(:is_validator, :boolean, default: false)
    field(:likelihood, :decimal)
    field(:block_reward_ratio, :decimal)
    field(:staked_ratio, :decimal)
    field(:self_staked_amount, Wei)
    field(:staked_amount, Wei)
    field(:was_banned_count, :integer)
    field(:was_validator_count, :integer)
    field(:is_deleted, :boolean, default: false)
    has_many(:delegators, StakingPoolsDelegator, foreign_key: :pool_address_hash)

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
    if get_field(changeset, :staked_amount) < get_field(changeset, :self_staked_amount) do
      add_error(changeset, :staked_amount, "must be greater than self_staked_amount")
    else
      changeset
    end
  end
end
