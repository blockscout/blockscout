defmodule Explorer.Chain.L2Block do
  use Ecto.Schema
  import Ecto.Changeset

  schema "l2_block" do
    field :active, :boolean, default: false
    field :l1_block, :integer, default: 0
    field :l2_block, :integer, default: 0
    field :chain, :string, default: "mantle"

    timestamps()
  end

  @doc false
  def changeset(l2_block, attrs) do
    l2_block
    |> cast(attrs, [:chain, :l1_block, :l2_block, :active])
    |> validate_required([:chain, :l1_block, :l2_block, :active])
  end
end
