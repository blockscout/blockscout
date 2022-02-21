defmodule Explorer.Chain.CeloPendingEpochOperation do
  @moduledoc """
  Tracks epoch blocks that have pending operations.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Repo

  @required_attrs ~w(block_hash fetch_epoch_rewards)a

  @typedoc """
   * `block_hash` - the hash of the epoch block that has pending operations.
   * `fetch_epoch_rewards` - if the epoch rewards should be fetched (or not)
  """
  @type t :: %__MODULE__{
          block_hash: Hash.Full.t(),
          fetch_epoch_rewards: boolean()
        }

  @primary_key false
  schema "celo_pending_epoch_operations" do
    field(:fetch_epoch_rewards, :boolean)
    field(:fetch_validator_group_data, :boolean)

    timestamps()

    belongs_to(:block, Block, foreign_key: :block_hash, primary_key: true, references: :hash, type: Hash.Full)
  end

  def changeset(%__MODULE__{} = celo_epoch_pending_ops, attrs) do
    celo_epoch_pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash, name: :celo_pending_epoch_operations_pkey)
  end

  def default_on_conflict do
    from(
      celo_epoch_pending_ops in __MODULE__,
      update: [
        set: [
          fetch_epoch_rewards: celo_epoch_pending_ops.fetch_epoch_rewards or fragment("EXCLUDED.fetch_epoch_rewards"),
          # Don't update `block_hash` as it is used for the conflict target
          inserted_at: celo_epoch_pending_ops.inserted_at,
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ],
      where: fragment("EXCLUDED.fetch_epoch_rewards <> ?", celo_epoch_pending_ops.fetch_epoch_rewards)
    )
  end

  @spec falsify_or_delete_celo_pending_epoch_operation(
          Hash.Full.t(),
          :fetch_epoch_rewards | :fetch_validator_group_data
        ) :: __MODULE__.t()
  def falsify_or_delete_celo_pending_epoch_operation(block_hash, operation_type) do
    celo_pending_operation = Repo.get(__MODULE__, block_hash)
    new_celo_pending_operation = Map.put(celo_pending_operation, operation_type, false)

    %{fetch_epoch_rewards: new_fetch_epoch_rewards, fetch_validator_group_data: new_fetch_validator_group_data} =
      new_celo_pending_operation

    if new_fetch_epoch_rewards || new_fetch_validator_group_data == true do
      celo_pending_operation
      |> changeset(%{
        block_hash: block_hash,
        fetch_epoch_rewards: new_fetch_epoch_rewards,
        fetch_validator_group_data: new_fetch_validator_group_data
      })
      |> Repo.update()
    else
      Repo.delete(celo_pending_operation)
    end
  end
end
