defmodule Explorer.Chain.Celo.EpochReward do
  @moduledoc """
  Represents the distributions in the Celo epoch. Each log index points to a
  token transfer event in the `TokenTransfer` relation. These include the
  reserve bolster, community, and carbon offsetting transfers.
  """
  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}

  @required_attrs ~w(block_hash)a
  @optional_attrs ~w(reserve_bolster_transfer_log_index community_transfer_log_index carbon_offsetting_transfer_log_index)a
  @allowed_attrs @required_attrs ++ @optional_attrs

  @primary_key false
  typed_schema "celo_epoch_rewards" do
    field(:reserve_bolster_transfer_log_index, :integer)
    field(:community_transfer_log_index, :integer)
    field(:carbon_offsetting_transfer_log_index, :integer)

    belongs_to(
      :block,
      Block,
      primary_key: true,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = rewards, attrs) do
    rewards
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash)
  end
end
