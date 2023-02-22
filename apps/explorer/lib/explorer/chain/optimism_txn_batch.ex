defmodule Explorer.Chain.OptimismTxnBatch do
  @moduledoc "Models a batch of transactions for Optimism."

  use Explorer.Schema

  alias Explorer.Chain.Hash

  @required_attrs ~w(l2_block_number epoch_number l1_tx_hashes l1_tx_timestamp)a

  @type t :: %__MODULE__{
          l2_block_number: non_neg_integer(),
          epoch_number: non_neg_integer(),
          l1_tx_hashes: [Hash.t()],
          l1_tx_timestamp: DateTime.t()
        }

  @primary_key false
  schema "op_transaction_batches" do
    field(:l2_block_number, :integer, primary_key: true)
    field(:epoch_number, :integer)
    field(:l1_tx_hashes, {:array, Hash.Full})
    field(:l1_tx_timestamp, :utc_datetime_usec)

    timestamps()
  end

  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end
end
