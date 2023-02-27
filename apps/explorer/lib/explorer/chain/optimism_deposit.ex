defmodule Explorer.Chain.OptimismDeposit do
  @moduledoc "Models a deposit for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(l1_block_number l1_block_timestamp l1_tx_hash l1_tx_origin l2_tx_hash)a

  @type t :: %__MODULE__{
          l1_block_number: non_neg_integer(),
          l1_block_timestamp: DateTime.t(),
          l1_tx_hash: Hash.t(),
          l1_tx_origin: Hash.t(),
          l2_tx_hash: Hash.t()
        }

  @primary_key false
  schema "op_output_roots" do
    field(:l1_block_number, :integer)
    field(:l1_block_timestamp, :utc_datetime_usec)
    field(:l1_tx_hash, Hash.Full)
    field(:l1_tx_origin, Hash.Address)
    field(:l2_tx_hash, Hash.Full, primary_key: true)

    timestamps()
  end

  def changeset(%__MODULE__{} = deposit, attrs \\ %{}) do
    deposit
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  def last_deposit_l1_block_number_query() do
    from(d in __MODULE__,
      order_by: [desc: d.l1_tx_origin],
      limit: 1
    )
  end
end
