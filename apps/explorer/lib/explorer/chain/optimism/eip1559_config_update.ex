defmodule Explorer.Chain.Optimism.EIP1559ConfigUpdate do
  @moduledoc "Models EIP-1559 config updates for Optimism (introduced by Holocene upgrade)."

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @required_attrs ~w(l2_block_number l2_block_hash base_fee_max_change_denominator elasticity_multiplier)a

  @typedoc """
    * `l2_block_number` - An L2 block number where the config update was registered.
    * `l2_block_hash` - An L2 block hash where the config update was registered.
    * `base_fee_max_change_denominator` - A new value of the denominator.
    * `elasticity_multiplier` - A new value of the multiplier.
  """
  @primary_key false
  typed_schema "op_eip1559_config_updates" do
    field(:l2_block_number, :integer, primary_key: true)
    field(:l2_block_hash, Hash.Full)
    field(:base_fee_max_change_denominator, :integer)
    field(:elasticity_multiplier, :integer)

    timestamps()
  end

  @doc """
    Validates that the attributes are valid.
  """
  def changeset(%__MODULE__{} = updates, attrs \\ %{}) do
    updates
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
    Reads the config actual before the specified block from the `op_eip1559_config_updates` table.

    ## Parameters
    - `block_number`: The block number for which we need to read the actual config.

    ## Returns
    - `{denominator, multiplier}` tuple in case the config exists.
    - `nil` if the config is unknown.
  """
  @spec actual_config_for_block(non_neg_integer()) :: {non_neg_integer(), non_neg_integer()} | nil
  def actual_config_for_block(block_number) do
    query =
      from(u in __MODULE__,
        select: {u.base_fee_max_change_denominator, u.elasticity_multiplier},
        where: u.l2_block_number < ^block_number,
        order_by: [desc: u.l2_block_number],
        limit: 1
      )

    Repo.one(query)
  end

  @doc """
    Reads the last row from the `op_eip1559_config_updates` table.

    ## Returns
    - `{l2_block_number, l2_block_hash}` tuple for the last row.
    - `{0, nil}` if there are no rows in the table.
  """
  @spec get_last_item() :: {non_neg_integer(), binary() | nil}
  def get_last_item do
    query =
      from(u in __MODULE__, select: {u.l2_block_number, u.l2_block_hash}, order_by: [desc: u.l2_block_number], limit: 1)

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  @doc """
    Removes rows from the `op_eip1559_config_updates` table which relate to
    pre-Holocene period or which have l2_block_number greater than the latest block number.
    They could be created mistakenly as a result of the incorrect value of
    INDEXER_OPTIMISM_L2_HOLOCENE_TIMESTAMP env variable or due to reorg.

    ## Parameters
    - `block_number`: L2 block number of the Holocene upgrade.
    - `latest_block_number`: The latest block number.

    ## Returns
    - A number of removed rows.
  """
  @spec remove_invalid_updates(non_neg_integer(), integer()) :: non_neg_integer()

  def remove_invalid_updates(0, latest_block_number) do
    {deleted_count, _} =
      Repo.delete_all(from(u in __MODULE__, where: u.l2_block_number > ^latest_block_number), timeout: :infinity)

    deleted_count
  end

  def remove_invalid_updates(block_number, latest_block_number) do
    {deleted_count, _} =
      Repo.delete_all(
        from(u in __MODULE__, where: u.l2_block_number < ^block_number or u.l2_block_number > ^latest_block_number),
        timeout: :infinity
      )

    deleted_count
  end
end
