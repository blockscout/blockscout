defmodule Explorer.Chain.Optimism.EIP1559ConfigUpdate do
  @moduledoc "Models EIP-1559 config updates for Optimism (introduced by Holocene upgrade)."

  use Explorer.Schema

  alias Explorer.Chain.Hash

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

  def changeset(%__MODULE__{} = updates, attrs \\ %{}) do
    updates
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
