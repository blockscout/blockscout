defmodule Explorer.Chain.StakingPool do
  @moduledoc """
  The representation of staking pool from POSDAO network.
  Staking pools might be candidate or validator.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Explorer.Chain.{
    Wei,
    Address,
    Hash
  }

  @attrs ~w(
    is_active delegators_count staked_amount self_staked_amount is_validator
    was_validator_count is_banned was_banned_count banned_until likelihood
    staked_ratio min_delegator_stake min_candidate_stake
    staking_address_hash mining_address_hash
  )a

  schema "staking_pools" do
    field(:banned_until, :integer)
    field(:delegators_count, :integer)
    field(:is_active, :boolean, default: false)
    field(:is_banned, :boolean, default: false)
    field(:is_validator, :boolean, default: false)
    field(:likelihood, :decimal)
    field(:staked_ratio, :decimal)
    field(:min_candidate_stake, Wei)
    field(:min_delegator_stake, Wei)
    field(:self_staked_amount, Wei)
    field(:staked_amount, Wei)
    field(:was_banned_count, :integer)
    field(:was_validator_count, :integer)
    field(:is_deleted, :boolean, default: false)

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
    |> validate_required(@attrs)
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
