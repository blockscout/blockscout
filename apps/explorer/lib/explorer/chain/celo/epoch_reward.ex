defmodule Explorer.Chain.Celo.EpochReward do
  # todo: write doc
  @moduledoc false
  use Explorer.Schema

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Celo.EpochReward
  alias Explorer.Repo
  alias Explorer.Chain.{Block, Hash, TokenTransfer}

  @required_attrs ~w(block_hash)a
  @optional_attrs ~w(reserve_bolster_transfer_log_index community_transfer_log_index carbon_offsetting_transfer_log_index)a
  @allowed_attrs @required_attrs ++ @optional_attrs

  @primary_key false
  typed_schema "celo_epoch_rewards" do
    field(:reserve_bolster_transfer_log_index, :integer)
    field(:community_transfer_log_index, :integer)
    field(:carbon_offsetting_transfer_log_index, :integer)
    field(:reserve_bolster_transfer, :any, virtual: true)
    field(:community_transfer, :any, virtual: true)
    field(:carbon_offsetting_transfer, :any, virtual: true)

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
    |> foreign_key_constraint(:reserve_bolster_transfer_log_index)
    |> foreign_key_constraint(:community_transfer_log_index)
    |> foreign_key_constraint(:carbon_offsetting_transfer_log_index)
  end

  @spec load_token_transfers(EpochReward.t()) :: EpochReward.t()
  def load_token_transfers(
        %EpochReward{
          reserve_bolster_transfer_log_index: reserve_bolster_transfer_log_index,
          community_transfer_log_index: community_transfer_log_index,
          carbon_offsetting_transfer_log_index: carbon_offsetting_transfer_log_index
        } = epoch_reward
      ) do
    virtual_field_to_log_index = [
      reserve_bolster_transfer: reserve_bolster_transfer_log_index,
      community_transfer: community_transfer_log_index,
      carbon_offsetting_transfer: carbon_offsetting_transfer_log_index
    ]

    log_indexes =
      virtual_field_to_log_index
      |> Enum.map(&elem(&1, 1))
      |> Enum.reject(&is_nil/1)

    query =
      from(
        tt in TokenTransfer.only_consensus_transfers_query(),
        where: tt.log_index in ^log_indexes and tt.block_hash == ^epoch_reward.block_hash,
        select: {tt.log_index, tt},
        preload: [
          :token,
          [from_address: [:names, :smart_contract, :proxy_implementations]],
          [to_address: [:names, :smart_contract, :proxy_implementations]]
        ]
      )

    log_index_to_token_transfer = query |> Repo.all() |> Map.new()

    Enum.reduce(virtual_field_to_log_index, epoch_reward, fn
      {field, log_index}, acc ->
        token_transfer = Map.get(log_index_to_token_transfer, log_index)
        Map.put(acc, field, token_transfer)
    end)
  end
end
