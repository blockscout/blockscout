defmodule Explorer.Chain.L1ToL2 do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          hash: Hash.Full.t(),
          l2_hash: Hash.Full.t(),
          block: integer(),
          timestamp: DateTime.t(),
          tx_origin: %Ecto.Association.NotLoaded{} | Address.t(),
          queue_index: integer(),
          target: %Ecto.Association.NotLoaded{} | Address.t(),
          gas_limit: Gas.t(),
        }

  @primary_key {:queue_index, :integer, autogenerate: false}
  schema "l1_to_l2" do
    field(:hash, :string)
    field(:l2_hash, :string)
    field(:block, :integer)
    field(:timestamp, :utc_datetime_usec)
    field(:tx_origin, :string)
    field(:target, :string)
    field(:gas_limit, :decimal)
    timestamps()
  end

  @doc false
  def changeset(l1_to_l2, attrs) do
    l1_to_l2
    |> cast(attrs, [])
    |> validate_required([])
  end
end
