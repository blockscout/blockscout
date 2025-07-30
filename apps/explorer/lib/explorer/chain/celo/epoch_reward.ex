defmodule Explorer.Chain.Celo.EpochReward do
  @moduledoc """
  Represents the distributions in the Celo epoch. Each log index points to a
  token transfer event in the `TokenTransfer` relation. These include the
  reserve bolster, community, and carbon offsetting transfers.
  """
  use Explorer.Schema

  alias Explorer.Chain.{Celo.Epoch, TokenTransfer}

  @required_attrs ~w(epoch_number)a
  @optional_attrs ~w(reserve_bolster_transfer_log_index community_transfer_log_index carbon_offsetting_transfer_log_index)a
  # @optional_attrs [
  #   :reserve_bolster_transfer_log_index,
  #   :reserve_bolster_transfer_value,
  #   :community_transfer_log_index,
  #   :community_transfer_value,
  #   :carbon_offsetting_transfer_log_index,
  #   :carbon_offsetting_transfer_value
  # ]
  @allowed_attrs @required_attrs ++ @optional_attrs

  @primary_key false
  typed_schema "celo_epoch_rewards" do
    field(:reserve_bolster_transfer_log_index, :integer)
    # field(:reserve_bolster_transfer_value, :integer)
    field(:community_transfer_log_index, :integer)
    # field(:community_transfer_value, :integer)
    field(:carbon_offsetting_transfer_log_index, :integer)
    # field(:carbon_offsetting_transfer_value, :integer)
    field(:reserve_bolster_transfer, :any, virtual: true) :: TokenTransfer.t() | nil
    field(:community_transfer, :any, virtual: true) :: TokenTransfer.t() | nil
    field(:carbon_offsetting_transfer, :any, virtual: true) :: TokenTransfer.t() | nil

    belongs_to(:epoch, Epoch,
      primary_key: true,
      foreign_key: :epoch_number,
      references: :number,
      type: :integer
    )

    timestamps()
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = rewards, attrs) do
    rewards
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash)
  end
end
