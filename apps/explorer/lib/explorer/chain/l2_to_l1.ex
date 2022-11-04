defmodule Explorer.Chain.L2ToL1 do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
        hash: Hash.Full.t(),
        l2_hash: Hash.Full.t(),
        block: integer(),
        msg_nonce: integer(),
        from_address: %Ecto.Association.NotLoaded{} | Address.t(),
        txn_batch_index: integer(),
        state_batch_index: integer(),
        timestamp: DateTime.t(),
        status: String.t(),
        gas_limit: Gas.t(),
      }
  schema "l2_to_l1" do
    field(:hash, :string)
    field(:l2_hash, :string)
    field(:block, :integer)
    field(:msg_nonce, :integer)
    field(:from_address, :string)
    field(:txn_batch_index, :integer)
    field(:state_batch_index, :integer)
    field(:timestamp, :utc_datetime_usec)
    field(:status, :string)
    field(:gas_limit, :decimal)
    timestamps()
  end

  @doc false
  def changeset(l2_to_l1, attrs) do
    l2_to_l1
    |> cast(attrs, [])
    |> validate_required([])
  end
end
